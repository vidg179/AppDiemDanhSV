using System.ComponentModel.DataAnnotations;
using BaKhi_API.Models;

namespace BaKhi_API.Dtos;

// ---------- Auth ----------
public record RegisterRequest(
    [Required, RegularExpression(@"^[a-zA-Z0-9_.]{3,30}$", ErrorMessage = "Tên đăng nhập 3-30 ký tự, chỉ gồm chữ, số, _ và .")] string Username,
    [Required, EmailAddress] string Email,
    [Required, MinLength(6)] string Password,
    [Required, MaxLength(100)] string FullName,
    [RegularExpression(@"^\+?[0-9]{9,15}$", ErrorMessage = "Số điện thoại không hợp lệ")] string? Phone,
    string? StudentCode);

public record LoginRequest(
    [Required] string Username,
    [Required] string Password,
    [RegularExpression("^(email|sms)$", ErrorMessage = "otpChannel phải là email hoặc sms")] string? OtpChannel);

public record VerifyOtpRequest([Required] string Ticket, [Required, StringLength(6, MinimumLength = 6)] string Code);

public record ResendOtpRequest([Required] string Ticket);

public record GoogleLoginRequest([Required] string IdToken);

public record ForgotPasswordRequest(
    [Required] string Username,
    [RegularExpression("^(email|sms)$", ErrorMessage = "otpChannel phải là email hoặc sms")] string? OtpChannel);

public record ResetPasswordRequest(
    [Required] string Ticket,
    [Required, StringLength(6, MinimumLength = 6)] string Code,
    [Required, MinLength(6)] string NewPassword);

// ---------- Face ----------
/// <param name="Embeddings">1-5 vector khuôn mặt (MobileFaceNet: 192 số/vector), nên chụp 3 góc.</param>
/// <param name="Password">Mật khẩu hiện tại để xác nhận (bỏ trống nếu tài khoản Google chưa đặt mật khẩu).</param>
public record RegisterFaceRequest([Required, MinLength(1), MaxLength(5)] List<List<double>> Embeddings, string? Password);

public record FaceEmbeddingRequest([Required] List<double> Embedding);

public record FaceLoginRequest([Required] string Username, [Required] List<double> Embedding);

public record FaceRegisteredResponse(int Samples, int Dimension, DateTime UpdatedAt);

public record FaceVerifyResponse(bool Match, double Similarity, double Threshold);

public record OtpChallengeResponse(
    string Ticket, string Purpose, string Channel, string Destination, DateTime ExpiresAt, string? DevCode);

public record AuthResponse(string Token, DateTime ExpiresAt, UserDto User);

// ---------- Users ----------
public record UserDto(
    string Id, string Username, string Email, string FullName, string? Phone, string Role,
    string? StudentCode, bool EmailVerified, string Provider, bool HasFace, DateTime CreatedAt)
{
    public static UserDto From(AppUser u) =>
        new(u.Id, u.Username, u.Email, u.FullName, u.Phone, u.Role, u.StudentCode, u.EmailVerified, u.Provider,
            u.HasFace, u.CreatedAt);
}

public record CreateUserRequest(
    [Required, RegularExpression(@"^[a-zA-Z0-9_.]{3,30}$")] string Username,
    [Required, EmailAddress] string Email,
    [Required, MinLength(6)] string Password,
    [Required, MaxLength(100)] string FullName,
    [Required, RegularExpression("^(admin|teacher|student)$")] string Role,
    [RegularExpression(@"^\+?[0-9]{9,15}$")] string? Phone,
    string? StudentCode);

public record UpdateUserRequest(
    [Required, EmailAddress] string Email,
    [Required, MaxLength(100)] string FullName,
    [Required, RegularExpression("^(admin|teacher|student)$")] string Role,
    [RegularExpression(@"^\+?[0-9]{9,15}$")] string? Phone,
    string? StudentCode,
    [MinLength(6)] string? NewPassword);

public record UpdateProfileRequest(
    [Required, MaxLength(100)] string FullName,
    [RegularExpression(@"^\+?[0-9]{9,15}$")] string? Phone);

public record ChangePasswordRequest(string? CurrentPassword, [Required, MinLength(6)] string NewPassword);

// ---------- Classes ----------
public record ClassDto(
    string Id, string Code, string Name, string? Subject, string? Room,
    string? TeacherId, string? TeacherName, int StudentCount, DateTime CreatedAt);

public record SaveClassRequest(
    [Required, MaxLength(30)] string Code,
    [Required, MaxLength(150)] string Name,
    string? Subject,
    string? Room,
    string? TeacherId);

public record AddStudentsRequest([Required, MinLength(1)] List<string> StudentIds);

// ---------- Sessions ----------
public record SessionDto(
    string Id, string ClassId, string Title, DateTime StartTime, DateTime EndTime,
    double? Latitude, double? Longitude, double RadiusMeters, bool RequireFace, string? QrToken, DateTime? QrExpiresAt)
{
    public static SessionDto From(ClassSession s, bool includeQr) =>
        new(s.Id, s.ClassId, s.Title, s.StartTime, s.EndTime, s.Latitude, s.Longitude, s.RadiusMeters, s.RequireFace,
            includeQr ? s.QrToken : null, includeQr ? s.QrExpiresAt : null);
}

public record SaveSessionRequest(
    [Required, MaxLength(150)] string Title,
    DateTimeOffset StartTime,
    DateTimeOffset EndTime,
    [Range(-90, 90)] double? Latitude,
    [Range(-180, 180)] double? Longitude,
    [Range(10, 5000)] double? RadiusMeters,
    bool RequireFace = false);

public record GenerateQrRequest([Range(1, 120)] int ValidMinutes = 5);

public record QrResponse(string SessionId, string QrToken, DateTime ExpiresAt);

// ---------- Attendance ----------
public record AttendanceDto(
    string Id, string SessionId, string ClassId, string StudentId, string Status, string Method,
    DateTime? CheckInTime, double? Latitude, double? Longitude, bool FaceVerified, string? Note)
{
    public static AttendanceDto From(AttendanceRecord a) =>
        new(a.Id, a.SessionId, a.ClassId, a.StudentId, a.Status, a.Method, a.CheckInTime, a.Latitude, a.Longitude,
            a.FaceVerified, a.Note);
}

public record CheckInRequest(
    [Required] string QrToken,
    [Range(-90, 90)] double? Latitude,
    [Range(-180, 180)] double? Longitude,
    List<double>? FaceEmbedding);

public record MarkAttendanceRequest(
    [Required] string SessionId,
    [Required] string StudentId,
    [Required, RegularExpression("^(present|late|absent|excused)$")] string Status,
    string? Note);

public record UpdateAttendanceRequest(
    [Required, RegularExpression("^(present|late|absent|excused)$")] string Status,
    string? Note);

public record RosterItemDto(
    string StudentId, string FullName, string? StudentCode, string? AttendanceId,
    string Status, string? Method, DateTime? CheckInTime, string? Note,
    double? Latitude, double? Longitude, double? DistanceMeters, bool FaceVerified);

public record StudentStatsDto(
    string StudentId, string FullName, string? StudentCode,
    int Present, int Late, int Excused, int Absent, double AbsentPercent, bool Warning);

// ---------- Absence requests ----------
public class CreateAbsenceRequestForm
{
    [Required] public string SessionId { get; set; } = "";

    [Required, MaxLength(1000)] public string Reason { get; set; } = "";

    /// <summary>sick (ốm), family (việc gia đình), event (hoạt động trường), other (khác)</summary>
    [RegularExpression("^(sick|family|event|other)$")] public string? Category { get; set; }

    /// <summary>Ảnh JPG/PNG/WEBP hoặc PDF, mỗi file tối đa 800 KB.</summary>
    public List<IFormFile>? Files { get; set; }
}

public class AddEvidenceForm
{
    [Required] public List<IFormFile> Files { get; set; } = [];
}

public record ReviewAbsenceRequest(
    [Required, RegularExpression("^(approved|rejected)$")] string Status,
    [MaxLength(500)] string? Note);

public record EvidenceDto(string Id, string FileName, string ContentType, long Size, string Url);

public record AbsenceRequestDto(
    string Id, string StudentId, string StudentName, string? StudentCode,
    string ClassId, string ClassName, string SessionId, string SessionTitle, DateTime SessionStart,
    string Category, string Reason, string Status, List<EvidenceDto> Evidence,
    string? ReviewerName, string? ReviewNote, DateTime? ReviewedAt, DateTime CreatedAt)
{
    public static AbsenceRequestDto From(AbsenceRequest r) =>
        new(r.Id, r.StudentId, r.StudentName, r.StudentCode, r.ClassId, r.ClassName, r.SessionId, r.SessionTitle,
            r.SessionStart, r.Category, r.Reason, r.Status,
            r.Evidence.Select(e => new EvidenceDto(e.Id, e.FileName, e.ContentType, e.Size,
                $"/api/absence-requests/{r.Id}/evidence/{e.Id}")).ToList(),
            r.ReviewerName, r.ReviewNote, r.ReviewedAt, r.CreatedAt);
}

public record ClassStatsDto(string ClassId, int TotalSessions, double WarningThresholdPercent, List<StudentStatsDto> Students);
