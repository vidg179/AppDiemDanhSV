using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using BaKhi_API.Services;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace BaKhi_API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(
    FirestoreContext ctx,
    OtpService otp,
    JwtService jwt,
    FaceService face,
    IOptions<GoogleAuthOptions> google) : ControllerBase
{
    /// <summary>Đăng ký tài khoản sinh viên bằng email. Trả về ticket OTP để xác minh email.</summary>
    [HttpPost("register")]
    public async Task<OtpChallengeResponse> Register(RegisterRequest req)
    {
        var email = req.Email.Trim().ToLowerInvariant();
        if (await ctx.FindUserByUsernameAsync(req.Username) is not null)
            throw AppException.Conflict("Tên đăng nhập đã tồn tại");
        if (await ctx.FindUserByEmailAsync(email) is not null)
            throw AppException.Conflict("Email đã được sử dụng");

        var user = new AppUser
        {
            Username = req.Username.Trim(),
            UsernameLower = req.Username.Trim().ToLowerInvariant(),
            Email = email,
            FullName = req.FullName.Trim(),
            Phone = req.Phone,
            StudentCode = req.StudentCode,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
            Role = AppRoles.Student,
        };
        user.Id = (await ctx.Users.AddAsync(user)).Id;
        return await otp.SendAsync(user, OtpPurposes.VerifyEmail, "email");
    }

    /// <summary>Bước 1 đăng nhập: kiểm tra tên đăng nhập/email + mật khẩu, gửi OTP qua email hoặc SMS.</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest req)
    {
        var user = await ctx.FindUserByLoginAsync(req.Username.Trim());
        if (user?.PasswordHash is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            throw AppException.Unauthorized("Sai tên đăng nhập hoặc mật khẩu");

        // Tài khoản demo (do cấu hình server tạo): vào thẳng, không cần OTP.
        if (user.OtpExempt) return Ok(jwt.CreateAuthResponse(user));

        if (!user.EmailVerified)
            return Ok(await otp.SendAsync(user, OtpPurposes.VerifyEmail, "email"));
        return Ok(await otp.SendAsync(user, OtpPurposes.Login, req.OtpChannel ?? "email"));
    }

    /// <summary>Bước 2: nhập mã OTP → nhận JWT token + thông tin user (có role để điều hướng).</summary>
    [HttpPost("verify-otp")]
    public async Task<AuthResponse> VerifyOtp(VerifyOtpRequest req)
    {
        var ticket = await otp.VerifyAsync(req.Ticket, req.Code, OtpPurposes.Login, OtpPurposes.VerifyEmail);
        var user = await FirestoreContext.GetAsync<AppUser>(ctx.Users, ticket.UserId)
                   ?? throw AppException.NotFound("Không tìm thấy người dùng");

        if (ticket.Purpose == OtpPurposes.VerifyEmail && !user.EmailVerified)
        {
            await ctx.Users.Document(user.Id).UpdateAsync(nameof(AppUser.EmailVerified), true);
            user.EmailVerified = true;
        }
        return jwt.CreateAuthResponse(user);
    }

    [HttpPost("resend-otp")]
    public Task<OtpChallengeResponse> ResendOtp(ResendOtpRequest req) => otp.ResendAsync(req.Ticket);

    /// <summary>Quên mật khẩu bước 1: gửi OTP (email/SMS) tới tài khoản theo tên đăng nhập hoặc email.</summary>
    [HttpPost("forgot-password")]
    public async Task<OtpChallengeResponse> ForgotPassword(ForgotPasswordRequest req)
    {
        var user = await ctx.FindUserByLoginAsync(req.Username.Trim())
                   ?? throw AppException.NotFound("Không tìm thấy tài khoản");
        return await otp.SendAsync(user, OtpPurposes.ResetPassword, req.OtpChannel ?? "email");
    }

    /// <summary>Quên mật khẩu bước 2: nhập OTP + mật khẩu mới → đặt lại và đăng nhập luôn.</summary>
    [HttpPost("reset-password")]
    public async Task<AuthResponse> ResetPassword(ResetPasswordRequest req)
    {
        var ticket = await otp.VerifyAsync(req.Ticket, req.Code, OtpPurposes.ResetPassword);
        var user = await FirestoreContext.GetAsync<AppUser>(ctx.Users, ticket.UserId)
                   ?? throw AppException.NotFound("Không tìm thấy người dùng");

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        if (ticket.Channel == "email") user.EmailVerified = true;
        await ctx.Users.Document(user.Id).UpdateAsync(new Dictionary<string, object>
        {
            [nameof(AppUser.PasswordHash)] = user.PasswordHash,
            [nameof(AppUser.EmailVerified)] = user.EmailVerified,
        });
        return jwt.CreateAuthResponse(user);
    }

    /// <summary>Đăng nhập bằng khuôn mặt: tên đăng nhập + vector khuôn mặt (đã đăng ký trước trong Hồ sơ).</summary>
    [HttpPost("face-login")]
    public async Task<AuthResponse> FaceLogin(FaceLoginRequest req)
    {
        var user = await ctx.FindUserByLoginAsync(req.Username.Trim())
                   ?? throw AppException.Unauthorized("Không tìm thấy tài khoản");
        if (!user.HasFace)
            throw AppException.BadRequest("Tài khoản chưa đăng ký khuôn mặt, hãy đăng nhập bằng mật khẩu rồi đăng ký trong Hồ sơ");

        var result = await face.VerifyAsync(user.Id, req.Embedding, countFailures: true);
        if (!result.Match) throw AppException.Unauthorized("Khuôn mặt không khớp");
        return jwt.CreateAuthResponse(user);
    }

    /// <summary>Đăng nhập/đăng ký bằng Google (OAuth 2.0). Flutter gửi idToken lấy từ google_sign_in.</summary>
    [HttpPost("google")]
    public async Task<AuthResponse> Google(GoogleLoginRequest req)
    {
        if (google.Value.ClientIds.Count == 0)
            throw AppException.BadRequest("Server chưa cấu hình Google:ClientIds");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(req.IdToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = google.Value.ClientIds });
        }
        catch (InvalidJwtException)
        {
            throw AppException.Unauthorized("Google token không hợp lệ");
        }
        if (!payload.EmailVerified)
            throw AppException.Unauthorized("Email Google chưa được xác minh");

        var email = payload.Email.ToLowerInvariant();
        var user = await ctx.FindUserByEmailAsync(email);
        if (user is null)
        {
            user = new AppUser
            {
                Username = await UniqueUsernameAsync(email),
                Email = email,
                FullName = string.IsNullOrWhiteSpace(payload.Name) ? email : payload.Name,
                Role = AppRoles.Student,
                EmailVerified = true,
                Provider = "google",
            };
            user.UsernameLower = user.Username.ToLowerInvariant();
            user.Id = (await ctx.Users.AddAsync(user)).Id;
        }
        else if (!user.EmailVerified)
        {
            await ctx.Users.Document(user.Id).UpdateAsync(nameof(AppUser.EmailVerified), true);
            user.EmailVerified = true;
        }
        return jwt.CreateAuthResponse(user);
    }

    private async Task<string> UniqueUsernameAsync(string email)
    {
        var baseName = new string(email.Split('@')[0].Where(c => char.IsAsciiLetterOrDigit(c) || c is '_' or '.').ToArray());
        if (baseName.Length < 3) baseName = "user" + baseName;
        if (baseName.Length > 24) baseName = baseName[..24];
        var name = baseName;
        while (await ctx.FindUserByUsernameAsync(name) is not null)
            name = $"{baseName}{Random.Shared.Next(1000, 9999)}";
        return name;
    }
}
