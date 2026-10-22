using System.Net;
using System.Net.Http.Headers;
using System.Net.Mail;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace BaKhi_API.Services;

public class JwtService(IOptions<JwtOptions> options)
{
    public AuthResponse CreateAuthResponse(AppUser user)
    {
        var o = options.Value;
        var expires = DateTime.UtcNow.AddHours(o.ExpiresHours);
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = o.Issuer,
            Audience = o.Audience,
            Expires = expires,
            Subject = new ClaimsIdentity(
            [
                new Claim("sub", user.Id),
                new Claim("role", user.Role),
                new Claim("name", user.FullName),
                new Claim("email", user.Email),
            ]),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(o.Key)), SecurityAlgorithms.HmacSha256),
        };
        var token = new JsonWebTokenHandler().CreateToken(descriptor);
        return new AuthResponse(token, expires, UserDto.From(user));
    }
}

public class NotificationService(
    HttpClient http,
    IOptions<SmtpOptions> smtp,
    IOptions<TwilioOptions> twilio,
    ILogger<NotificationService> logger)
{
    public async Task SendEmailAsync(string to, string subject, string body)
    {
        var o = smtp.Value;
        if (string.IsNullOrWhiteSpace(o.Host) || string.IsNullOrWhiteSpace(o.User))
        {
            logger.LogWarning("SMTP chưa cấu hình. Email tới {To} | {Subject} | {Body}", to, subject, body);
            return;
        }
        using var client = new SmtpClient(o.Host, o.Port)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(o.User, o.Password),
        };
        using var message = new MailMessage(
            new MailAddress(string.IsNullOrWhiteSpace(o.From) ? o.User : o.From, "Điểm danh HUTECH", Encoding.UTF8),
            new MailAddress(to))
        {
            Subject = subject,
            Body = body,
            SubjectEncoding = Encoding.UTF8,
            BodyEncoding = Encoding.UTF8,
        };
        try
        {
            await client.SendMailAsync(message);
        }
        catch (SmtpException ex)
        {
            logger.LogError(ex, "Gửi email thất bại");
            throw new AppException(StatusCodes.Status502BadGateway, "Không gửi được email OTP, thử lại sau");
        }
    }

    /// <summary>Gửi email thông báo không quan trọng: lỗi chỉ ghi log, không làm hỏng request.</summary>
    public async Task TrySendEmailAsync(string? to, string subject, string body)
    {
        if (string.IsNullOrWhiteSpace(to)) return;
        try
        {
            await SendEmailAsync(to, subject, body);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Không gửi được email thông báo tới {To}", to);
        }
    }

    public async Task SendSmsAsync(string phone, string text)
    {
        var o = twilio.Value;
        var to = ToE164(phone);
        if (string.IsNullOrWhiteSpace(o.AccountSid) || string.IsNullOrWhiteSpace(o.AuthToken))
        {
            logger.LogWarning("Twilio chưa cấu hình. SMS tới {To} | {Text}", to, text);
            return;
        }
        using var request = new HttpRequestMessage(HttpMethod.Post,
            $"https://api.twilio.com/2010-04-01/Accounts/{o.AccountSid}/Messages.json")
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["To"] = to,
                ["From"] = o.From,
                ["Body"] = text,
            }),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Basic",
            Convert.ToBase64String(Encoding.ASCII.GetBytes($"{o.AccountSid}:{o.AuthToken}")));
        var response = await http.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogError("Twilio lỗi {Status}: {Body}", response.StatusCode, await response.Content.ReadAsStringAsync());
            throw new AppException(StatusCodes.Status502BadGateway, "Không gửi được SMS OTP, thử lại sau");
        }
    }

    private static string ToE164(string phone) => phone.StartsWith('0') ? "+84" + phone[1..] : phone;
}

public class OtpService(FirestoreContext ctx, NotificationService notify, IOptions<OtpOptions> options)
{
    private OtpOptions O => options.Value;

    /// <summary>Tạo phiên OTP mới; phiên cũ cùng mục đích bị hủy, chặn gửi liên tục trong ResendSeconds.</summary>
    public async Task<OtpChallengeResponse> SendAsync(AppUser user, string purpose, string channel)
    {
        if (channel == "sms" && string.IsNullOrWhiteSpace(user.Phone))
            throw AppException.BadRequest("Tài khoản chưa có số điện thoại, hãy chọn OTP qua email");

        var previous = (await FirestoreContext.ListAsync<OtpTicket>(
                ctx.Otps.WhereEqualTo(nameof(OtpTicket.UserId), user.Id)))
            .Where(t => t.Purpose == purpose).ToList();
        var last = previous.MaxBy(t => t.SentAt);
        if (last is not null) EnsureCooldownPassed(last);
        foreach (var old in previous) await ctx.Otps.Document(old.Id).DeleteAsync();

        var ticket = new OtpTicket
        {
            Id = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)),
            UserId = user.Id,
            Purpose = purpose,
            Channel = channel,
        };
        return await IssueAsync(ticket, user);
    }

    public async Task<OtpChallengeResponse> ResendAsync(string ticketId)
    {
        var ticket = await FirestoreContext.GetAsync<OtpTicket>(ctx.Otps, ticketId)
                     ?? throw AppException.BadRequest("Phiên OTP không tồn tại, vui lòng đăng nhập lại");
        EnsureCooldownPassed(ticket);
        var user = await FirestoreContext.GetAsync<AppUser>(ctx.Users, ticket.UserId)
                   ?? throw AppException.NotFound("Không tìm thấy người dùng");
        return await IssueAsync(ticket, user);
    }

    /// <summary>Kiểm tra mã OTP; ticket chỉ dùng được cho đúng mục đích đã tạo (login, reset-password...).</summary>
    public async Task<OtpTicket> VerifyAsync(string ticketId, string code, params string[] allowedPurposes)
    {
        var ticket = await FirestoreContext.GetAsync<OtpTicket>(ctx.Otps, ticketId)
                     ?? throw AppException.BadRequest("Phiên OTP không tồn tại, vui lòng đăng nhập lại");
        if (!allowedPurposes.Contains(ticket.Purpose))
            throw AppException.BadRequest("Mã OTP này không dùng cho thao tác này");
        var doc = ctx.Otps.Document(ticket.Id);

        if (DateTime.UtcNow > ticket.ExpiresAt)
        {
            await doc.DeleteAsync();
            throw AppException.BadRequest("Mã OTP đã hết hạn");
        }
        if (ticket.Attempts >= O.MaxAttempts)
        {
            await doc.DeleteAsync();
            throw AppException.TooMany("Nhập sai quá nhiều lần, vui lòng đăng nhập lại");
        }
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(Hash(ticket.Id, code.Trim())), Encoding.UTF8.GetBytes(ticket.CodeHash)))
        {
            await doc.UpdateAsync(nameof(OtpTicket.Attempts), ticket.Attempts + 1);
            throw AppException.BadRequest($"Mã OTP không đúng (còn {O.MaxAttempts - ticket.Attempts - 1} lần)");
        }

        await doc.DeleteAsync();
        return ticket;
    }

    private void EnsureCooldownPassed(OtpTicket ticket)
    {
        var wait = ticket.SentAt.AddSeconds(O.ResendSeconds) - DateTime.UtcNow;
        if (wait > TimeSpan.Zero)
            throw AppException.TooMany($"Vui lòng chờ {Math.Ceiling(wait.TotalSeconds)} giây để gửi lại OTP");
    }

    private async Task<OtpChallengeResponse> IssueAsync(OtpTicket ticket, AppUser user)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var now = DateTime.UtcNow;
        ticket.CodeHash = Hash(ticket.Id, code);
        ticket.Attempts = 0;
        ticket.SentAt = now;
        ticket.ExpiresAt = now.AddMinutes(O.ExpiresMinutes);
        await ctx.Otps.Document(ticket.Id).SetAsync(ticket);

        string destination;
        if (ticket.Channel == "sms")
        {
            await notify.SendSmsAsync(user.Phone!, $"Ma OTP HUTECH cua ban la {code}. Het han sau {O.ExpiresMinutes} phut. Khong chia se ma nay.");
            destination = MaskPhone(user.Phone!);
        }
        else
        {
            var action = ticket.Purpose switch
            {
                OtpPurposes.VerifyEmail => "xác minh email",
                OtpPurposes.ResetPassword => "đặt lại mật khẩu",
                _ => "đăng nhập",
            };
            var body = string.Join(Environment.NewLine,
            [
                $"Xin chào {user.FullName},",
                "",
                $"Mã OTP {action} ứng dụng Điểm danh HUTECH của bạn là:",
                "",
                $"    {code}",
                "",
                $"Mã có hiệu lực trong {O.ExpiresMinutes} phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.",
                "Nếu bạn không thực hiện yêu cầu này, hãy bỏ qua email.",
                "",
                "Điểm danh HUTECH",
            ]);
            await notify.SendEmailAsync(user.Email, "Mã OTP HUTECH", body);
            destination = MaskEmail(user.Email);
        }

        return new OtpChallengeResponse(ticket.Id, ticket.Purpose, ticket.Channel, destination, ticket.ExpiresAt,
            O.ReturnCodeInResponse ? code : null);
    }

    private static string Hash(string ticketId, string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{ticketId}:{code}")));

    private static string MaskEmail(string email)
    {
        var at = email.IndexOf('@');
        return at <= 2 ? "***" + email[at..] : email[..2] + "***" + email[at..];
    }

    private static string MaskPhone(string phone) =>
        phone.Length <= 4 ? "****" : new string('*', phone.Length - 4) + phone[^4..];
}

/// <summary>
/// So khớp khuôn mặt bằng vector đặc trưng (embedding) do app tính trên điện thoại (ML Kit + MobileFaceNet).
/// Server chuẩn hóa vector rồi so cosine similarity với các mẫu đã đăng ký.
/// </summary>
public class FaceService(FirestoreContext ctx, IOptions<FaceOptions> options)
{
    private FaceOptions O => options.Value;

    public async Task<FaceProfile> RegisterAsync(AppUser user, List<List<double>> embeddings)
    {
        if (embeddings.Count is 0 || embeddings.Count > O.MaxSamples)
            throw AppException.BadRequest($"Cần 1-{O.MaxSamples} mẫu khuôn mặt");

        var samples = embeddings.Select(Normalize).ToList();
        var dimension = samples[0].Length;
        if (samples.Any(s => s.Length != dimension))
            throw AppException.BadRequest("Các mẫu khuôn mặt phải có cùng số chiều");
        for (var i = 0; i < samples.Count; i++)
        for (var j = i + 1; j < samples.Count; j++)
            if (Dot(samples[i], samples[j]) < O.MatchThreshold)
                throw AppException.BadRequest("Các ảnh mẫu không giống nhau (có thể không cùng 1 người), hãy chụp lại");

        var profile = new FaceProfile
        {
            Id = user.Id,
            Dimension = dimension,
            Samples = samples.Select(s => new FaceSample { Vector = [.. s] }).ToList(),
            UpdatedAt = DateTime.UtcNow,
        };
        var batch = ctx.Db.StartBatch();
        batch.Set(ctx.FaceProfiles.Document(user.Id), profile);
        batch.Update(ctx.Users.Document(user.Id), nameof(AppUser.HasFace), true);
        await batch.CommitAsync();
        return profile;
    }

    public async Task RemoveAsync(string userId)
    {
        var batch = ctx.Db.StartBatch();
        batch.Delete(ctx.FaceProfiles.Document(userId));
        batch.Update(ctx.Users.Document(userId), nameof(AppUser.HasFace), false);
        await batch.CommitAsync();
    }

    /// <summary>So khớp; nếu countFailures thì sai liên tiếp MaxFailedAttempts lần sẽ khóa LockMinutes phút.</summary>
    public async Task<FaceVerifyResponse> VerifyAsync(string userId, IReadOnlyList<double> embedding, bool countFailures)
    {
        var profile = await FirestoreContext.GetAsync<FaceProfile>(ctx.FaceProfiles, userId)
                      ?? throw AppException.BadRequest("Tài khoản chưa đăng ký khuôn mặt");
        var now = DateTime.UtcNow;
        if (profile.LockedUntil > now)
            throw AppException.TooMany(
                $"Sai khuôn mặt quá nhiều lần, thử lại sau {Math.Ceiling((profile.LockedUntil.Value - now).TotalMinutes)} phút");

        var probe = Normalize(embedding);
        if (probe.Length != profile.Dimension)
            throw AppException.BadRequest($"Vector khuôn mặt phải có {profile.Dimension} số (giống lúc đăng ký)");

        var similarity = profile.Samples.Max(s => Dot(probe, s.Vector));
        var match = similarity >= O.MatchThreshold;

        if (countFailures)
        {
            var doc = ctx.FaceProfiles.Document(userId);
            if (!match)
            {
                var failed = profile.FailedAttempts + 1;
                if (failed >= O.MaxFailedAttempts)
                    await doc.UpdateAsync(new Dictionary<string, object>
                    {
                        [nameof(FaceProfile.FailedAttempts)] = 0,
                        [nameof(FaceProfile.LockedUntil)] = now.AddMinutes(O.LockMinutes),
                    });
                else
                    await doc.UpdateAsync(nameof(FaceProfile.FailedAttempts), failed);
            }
            else if (profile.FailedAttempts > 0)
            {
                await doc.UpdateAsync(nameof(FaceProfile.FailedAttempts), 0);
            }
        }

        return new FaceVerifyResponse(match, Math.Round(similarity, 4), O.MatchThreshold);
    }

    private static double[] Normalize(IReadOnlyList<double> v)
    {
        if (v.Count is < 64 or > 1024) throw AppException.BadRequest("Vector khuôn mặt phải có 64-1024 số");
        if (v.Any(x => !double.IsFinite(x))) throw AppException.BadRequest("Vector khuôn mặt chứa giá trị không hợp lệ");
        var norm = Math.Sqrt(v.Sum(x => x * x));
        if (norm < 1e-9) throw AppException.BadRequest("Vector khuôn mặt không hợp lệ");
        return v.Select(x => x / norm).ToArray();
    }

    private static double Dot(IReadOnlyList<double> a, IReadOnlyList<double> b)
    {
        double sum = 0;
        for (var i = 0; i < a.Count; i++) sum += a[i] * b[i];
        return sum;
    }
}
