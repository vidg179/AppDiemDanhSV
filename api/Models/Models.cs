using Google.Cloud.Firestore;

namespace BaKhi_API.Models;

public static class AppRoles
{
    public const string Admin = "admin";
    public const string Teacher = "teacher";
    public const string Student = "student";
    public const string AdminOrTeacher = Admin + "," + Teacher;

    public static readonly string[] All = [Admin, Teacher, Student];
}

public static class AttendanceStatus
{
    public const string Present = "present";
    public const string Late = "late";
    public const string Absent = "absent";
    public const string Excused = "excused";
    public const string Pending = "pending";
}

public static class AttendanceMethods
{
    public const string Qr = "qr";
    public const string Manual = "manual";
    public const string AbsenceRequest = "absence-request";
}

public static class AbsenceStatus
{
    public const string Pending = "pending";
    public const string Approved = "approved";
    public const string Rejected = "rejected";
}

public static class OtpPurposes
{
    public const string Login = "login";
    public const string VerifyEmail = "verify-email";
    public const string ResetPassword = "reset-password";
}

[FirestoreData]
public class AppUser
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string Username { get; set; } = "";
    [FirestoreProperty] public string UsernameLower { get; set; } = "";
    [FirestoreProperty] public string Email { get; set; } = "";
    [FirestoreProperty] public string FullName { get; set; } = "";
    [FirestoreProperty] public string? Phone { get; set; }
    [FirestoreProperty] public string? PasswordHash { get; set; }
    [FirestoreProperty] public string Role { get; set; } = AppRoles.Student;
    [FirestoreProperty] public string? StudentCode { get; set; }
    [FirestoreProperty] public bool EmailVerified { get; set; }
    [FirestoreProperty] public string Provider { get; set; } = "local";
    [FirestoreProperty] public bool HasFace { get; set; }
    /// <summary>Chỉ tài khoản demo do cấu hình server tạo mới được bỏ qua OTP; không API nào bật được cờ này.</summary>
    [FirestoreProperty] public bool OtpExempt { get; set; }
    [FirestoreProperty] public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

[FirestoreData]
public class FaceSample
{
    [FirestoreProperty] public List<double> Vector { get; set; } = [];
}

/// <summary>Vector khuôn mặt (đã chuẩn hóa) của 1 user; document id = user id.</summary>
[FirestoreData]
public class FaceProfile
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public int Dimension { get; set; }
    [FirestoreProperty] public List<FaceSample> Samples { get; set; } = [];
    [FirestoreProperty] public int FailedAttempts { get; set; }
    [FirestoreProperty] public DateTime? LockedUntil { get; set; }
    [FirestoreProperty] public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

[FirestoreData]
public class ClassRoom
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string Code { get; set; } = "";
    [FirestoreProperty] public string Name { get; set; } = "";
    [FirestoreProperty] public string? Subject { get; set; }
    [FirestoreProperty] public string? Room { get; set; }
    [FirestoreProperty] public string? TeacherId { get; set; }
    [FirestoreProperty] public List<string> StudentIds { get; set; } = [];
    [FirestoreProperty] public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

[FirestoreData]
public class ClassSession
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string ClassId { get; set; } = "";
    [FirestoreProperty] public string Title { get; set; } = "";
    [FirestoreProperty] public DateTime StartTime { get; set; }
    [FirestoreProperty] public DateTime EndTime { get; set; }
    [FirestoreProperty] public double? Latitude { get; set; }
    [FirestoreProperty] public double? Longitude { get; set; }
    [FirestoreProperty] public double RadiusMeters { get; set; } = 100;
    [FirestoreProperty] public string? QrToken { get; set; }
    [FirestoreProperty] public DateTime? QrExpiresAt { get; set; }
    [FirestoreProperty] public bool RequireFace { get; set; }
    [FirestoreProperty] public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

[FirestoreData]
public class AttendanceRecord
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string SessionId { get; set; } = "";
    [FirestoreProperty] public string ClassId { get; set; } = "";
    [FirestoreProperty] public string StudentId { get; set; } = "";
    [FirestoreProperty] public string Status { get; set; } = AttendanceStatus.Present;
    [FirestoreProperty] public string Method { get; set; } = "qr";
    [FirestoreProperty] public DateTime? CheckInTime { get; set; }
    [FirestoreProperty] public double? Latitude { get; set; }
    [FirestoreProperty] public double? Longitude { get; set; }
    [FirestoreProperty] public bool FaceVerified { get; set; }
    [FirestoreProperty] public string? Note { get; set; }
    [FirestoreProperty] public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public static string MakeId(string sessionId, string studentId) => $"{sessionId}_{studentId}";
}

[FirestoreData]
public class EvidenceInfo
{
    [FirestoreProperty] public string Id { get; set; } = "";
    [FirestoreProperty] public string FileName { get; set; } = "";
    [FirestoreProperty] public string ContentType { get; set; } = "";
    [FirestoreProperty] public long Size { get; set; }
}

[FirestoreData]
public class AbsenceRequest
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string StudentId { get; set; } = "";
    [FirestoreProperty] public string StudentName { get; set; } = "";
    [FirestoreProperty] public string? StudentCode { get; set; }
    [FirestoreProperty] public string ClassId { get; set; } = "";
    [FirestoreProperty] public string ClassName { get; set; } = "";
    [FirestoreProperty] public string SessionId { get; set; } = "";
    [FirestoreProperty] public string SessionTitle { get; set; } = "";
    [FirestoreProperty] public DateTime SessionStart { get; set; }
    [FirestoreProperty] public string Category { get; set; } = "other";
    [FirestoreProperty] public string Reason { get; set; } = "";
    [FirestoreProperty] public string Status { get; set; } = AbsenceStatus.Pending;
    [FirestoreProperty] public List<EvidenceInfo> Evidence { get; set; } = [];
    [FirestoreProperty] public string? ReviewerId { get; set; }
    [FirestoreProperty] public string? ReviewerName { get; set; }
    [FirestoreProperty] public string? ReviewNote { get; set; }
    [FirestoreProperty] public DateTime? ReviewedAt { get; set; }
    [FirestoreProperty] public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>File minh chứng lưu trong Firestore (mỗi document tối đa 1 MB) để không cần Firebase Storage trả phí.</summary>
[FirestoreData]
public class EvidenceFile
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string RequestId { get; set; } = "";
    [FirestoreProperty] public byte[] Data { get; set; } = [];
}

[FirestoreData]
public class OtpTicket
{
    [FirestoreDocumentId] public string Id { get; set; } = "";
    [FirestoreProperty] public string UserId { get; set; } = "";
    [FirestoreProperty] public string Purpose { get; set; } = OtpPurposes.Login;
    [FirestoreProperty] public string Channel { get; set; } = "email";
    [FirestoreProperty] public string CodeHash { get; set; } = "";
    [FirestoreProperty] public int Attempts { get; set; }
    [FirestoreProperty] public DateTime SentAt { get; set; }
    [FirestoreProperty] public DateTime ExpiresAt { get; set; }
}
