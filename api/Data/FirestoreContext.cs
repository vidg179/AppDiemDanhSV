using System.Security.Claims;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;

namespace BaKhi_API.Data;

public class FirestoreContext(FirestoreDb db)
{
    public FirestoreDb Db => db;
    public CollectionReference Users => db.Collection("users");
    public CollectionReference Classes => db.Collection("classes");
    public CollectionReference Sessions => db.Collection("sessions");
    public CollectionReference Attendances => db.Collection("attendances");
    public CollectionReference Otps => db.Collection("otp_tickets");
    public CollectionReference AbsenceRequests => db.Collection("absence_requests");
    public CollectionReference EvidenceFiles => db.Collection("absence_evidence");
    public CollectionReference FaceProfiles => db.Collection("face_profiles");

    public static FirestoreDb Create(IConfiguration config, string contentRoot)
    {
        var section = config.GetSection("Firebase");
        var projectId = section["ProjectId"];
        if (string.IsNullOrWhiteSpace(projectId))
            throw new InvalidOperationException("Thiếu Firebase:ProjectId trong appsettings.json");

        var builder = new FirestoreDbBuilder
        {
            ProjectId = projectId,
            EmulatorDetection = Google.Api.Gax.EmulatorDetection.EmulatorOrProduction,
        };

        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("FIRESTORE_EMULATOR_HOST")))
        {
            var json = section["CredentialsJson"];
            var path = section["CredentialsPath"];
            if (string.IsNullOrWhiteSpace(json) && !string.IsNullOrWhiteSpace(path))
            {
                var fullPath = Path.IsPathRooted(path) ? path : Path.Combine(contentRoot, path);
                if (File.Exists(fullPath)) json = File.ReadAllText(fullPath);
            }
            if (string.IsNullOrWhiteSpace(json))
                throw new InvalidOperationException(
                    "Không tìm thấy service account Firebase. Đặt file firebase-key.json cạnh project " +
                    "hoặc set biến môi trường Firebase__CredentialsJson.");
            builder.GoogleCredential = CredentialFactory.FromJson<ServiceAccountCredential>(json).ToGoogleCredential();
        }

        return builder.Build();
    }

    public static async Task<T?> GetAsync<T>(CollectionReference col, string id) where T : class
    {
        if (string.IsNullOrWhiteSpace(id) || id.Contains('/')) return null;
        var snap = await col.Document(id).GetSnapshotAsync();
        return snap.Exists ? snap.ConvertTo<T>() : null;
    }

    public static async Task<List<T>> ListAsync<T>(Query query)
    {
        var snap = await query.GetSnapshotAsync();
        return snap.Documents.Select(d => d.ConvertTo<T>()).ToList();
    }

    public async Task<AppUser?> FindUserByUsernameAsync(string username) =>
        (await ListAsync<AppUser>(Users.WhereEqualTo(nameof(AppUser.UsernameLower), username.Trim().ToLowerInvariant()).Limit(1)))
        .FirstOrDefault();

    public async Task<AppUser?> FindUserByEmailAsync(string email) =>
        (await ListAsync<AppUser>(Users.WhereEqualTo(nameof(AppUser.Email), email.Trim().ToLowerInvariant()).Limit(1)))
        .FirstOrDefault();

    public async Task<AppUser?> FindUserByLoginAsync(string login) =>
        login.Contains('@') ? await FindUserByEmailAsync(login) : await FindUserByUsernameAsync(login);

    public async Task<List<AppUser>> GetUsersByIdsAsync(IEnumerable<string> ids)
    {
        var refs = ids.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().Select(id => Users.Document(id)).ToList();
        if (refs.Count == 0) return [];
        var snaps = await db.GetAllSnapshotsAsync(refs);
        return snaps.Where(s => s.Exists).Select(s => s.ConvertTo<AppUser>()).ToList();
    }

    /// <summary>Loads a class and enforces access: admin = all, teacher = own classes, student = enrolled (read only).</summary>
    public async Task<ClassRoom> GetClassAsync(string classId, ClaimsPrincipal user, bool manage)
    {
        var cls = await GetAsync<ClassRoom>(Classes, classId) ?? throw AppException.NotFound("Không tìm thấy lớp");
        var uid = user.UserId();
        var allowed = user.Role() switch
        {
            AppRoles.Admin => true,
            AppRoles.Teacher => cls.TeacherId == uid,
            AppRoles.Student => !manage && cls.StudentIds.Contains(uid),
            _ => false,
        };
        if (!allowed) throw AppException.Forbidden("Bạn không có quyền với lớp này");
        return cls;
    }

    public async Task<ClassSession> GetSessionAsync(string sessionId) =>
        await GetAsync<ClassSession>(Sessions, sessionId) ?? throw AppException.NotFound("Không tìm thấy buổi học");

    public async Task DeleteWhereAsync(CollectionReference col, string field, object value)
    {
        while (true)
        {
            var snap = await col.WhereEqualTo(field, value).Limit(400).GetSnapshotAsync();
            if (snap.Count == 0) return;
            var batch = db.StartBatch();
            foreach (var doc in snap.Documents) batch.Delete(doc.Reference);
            await batch.CommitAsync();
        }
    }

    public async Task DeleteAbsenceRequestAsync(AbsenceRequest request)
    {
        var batch = db.StartBatch();
        foreach (var file in request.Evidence) batch.Delete(EvidenceFiles.Document(file.Id));
        batch.Delete(AbsenceRequests.Document(request.Id));
        await batch.CommitAsync();
    }

    public async Task DeleteAbsenceRequestsWhereAsync(string field, string value)
    {
        foreach (var request in await ListAsync<AbsenceRequest>(AbsenceRequests.WhereEqualTo(field, value)))
            await DeleteAbsenceRequestAsync(request);
    }

    /// <summary>Tạo/cập nhật tài khoản demo (bỏ qua OTP) theo cấu hình; mật khẩu và vai trò luôn khớp cấu hình.</summary>
    public async Task SeedDemoAsync(DemoOptions options, ILogger logger)
    {
        foreach (var entry in options.Accounts.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var parts = entry.Split('|', StringSplitOptions.TrimEntries);
            if (parts.Length < 4 || parts[1].Length < 6 || !AppRoles.All.Contains(parts[2]))
            {
                logger.LogWarning("Bỏ qua cấu hình tài khoản demo không hợp lệ: {Name}", parts.FirstOrDefault());
                continue;
            }
            var (username, password, role, fullName) = (parts[0], parts[1], parts[2], parts[3]);
            var user = await FindUserByUsernameAsync(username) ?? new AppUser
            {
                Username = username,
                UsernameLower = username.ToLowerInvariant(),
                Email = $"{username.ToLowerInvariant()}@demo.hutech.local",
            };
            user.FullName = fullName;
            user.Role = role;
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
            user.EmailVerified = true;
            user.OtpExempt = true;
            if (string.IsNullOrEmpty(user.Id)) await Users.AddAsync(user);
            else await Users.Document(user.Id).SetAsync(user);
        }
    }

    public async Task SeedAdminAsync(SeedAdminOptions options, ILogger logger)
    {
        var existing = await Users.WhereEqualTo(nameof(AppUser.Role), AppRoles.Admin).Limit(1).GetSnapshotAsync();
        if (existing.Count > 0) return;
        if (string.IsNullOrWhiteSpace(options.Password) || string.IsNullOrWhiteSpace(options.Email))
        {
            logger.LogWarning("Chưa có tài khoản admin và SeedAdmin chưa cấu hình Email/Password, bỏ qua tạo admin.");
            return;
        }
        await Users.AddAsync(new AppUser
        {
            Username = options.Username,
            UsernameLower = options.Username.ToLowerInvariant(),
            Email = options.Email.ToLowerInvariant(),
            FullName = "Quản trị viên",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(options.Password),
            Role = AppRoles.Admin,
            EmailVerified = true,
        });
        logger.LogInformation("Đã tạo tài khoản admin '{Username}'", options.Username);
    }
}
