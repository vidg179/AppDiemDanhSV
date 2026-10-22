using System.Security.Claims;

namespace BaKhi_API.Infrastructure;

public class AppException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;

    public static AppException BadRequest(string m) => new(StatusCodes.Status400BadRequest, m);
    public static AppException Unauthorized(string m) => new(StatusCodes.Status401Unauthorized, m);
    public static AppException Forbidden(string m) => new(StatusCodes.Status403Forbidden, m);
    public static AppException NotFound(string m) => new(StatusCodes.Status404NotFound, m);
    public static AppException Conflict(string m) => new(StatusCodes.Status409Conflict, m);
    public static AppException TooMany(string m) => new(StatusCodes.Status429TooManyRequests, m);
}

public static class ClaimsExtensions
{
    public static string UserId(this ClaimsPrincipal user) =>
        user.FindFirstValue("sub") ?? throw AppException.Unauthorized("Chưa đăng nhập");

    public static string Role(this ClaimsPrincipal user) => user.FindFirstValue("role") ?? "";
}

public static class Geo
{
    public static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6_371_000;
        double ToRad(double d) => d * Math.PI / 180;
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * r * Math.Asin(Math.Sqrt(a));
    }
}

public class JwtOptions
{
    public string Issuer { get; set; } = "BaKhi_API";
    public string Audience { get; set; } = "BaKhi_App";
    public string Key { get; set; } = "";
    public int ExpiresHours { get; set; } = 24;
}

public class OtpOptions
{
    public int ExpiresMinutes { get; set; } = 5;
    public int MaxAttempts { get; set; } = 5;
    public int ResendSeconds { get; set; } = 30;
    public bool ReturnCodeInResponse { get; set; }
}

public class SmtpOptions
{
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;
    public string User { get; set; } = "";
    public string Password { get; set; } = "";
    public string From { get; set; } = "";
}

public class TwilioOptions
{
    public string AccountSid { get; set; } = "";
    public string AuthToken { get; set; } = "";
    public string From { get; set; } = "";
}

public class GoogleAuthOptions
{
    public List<string> ClientIds { get; set; } = [];
}

public class AttendanceOptions
{
    public int LateAfterMinutes { get; set; } = 15;
    public double AbsentWarningPercent { get; set; } = 20;
}

public class FaceOptions
{
    /// <summary>Cosine similarity tối thiểu để coi là cùng 1 người (0.5 ≈ khoảng cách Euclid 1.0 của MobileFaceNet).</summary>
    public double MatchThreshold { get; set; } = 0.5;
    public int MaxSamples { get; set; } = 5;
    public int MaxFailedAttempts { get; set; } = 5;
    public int LockMinutes { get; set; } = 5;
}

public class AbsenceOptions
{
    public int MaxDaysAfterSession { get; set; } = 7;
    public int MaxFiles { get; set; } = 5;
    public int MaxFileSizeKb { get; set; } = 800;
}

public class DemoOptions
{
    /// <summary>Danh sách "tên|mật khẩu|vai trò|họ tên" cách nhau bằng dấu ";". Để trống thì tắt tài khoản demo.</summary>
    public string Accounts { get; set; } = "";
}

public class SeedAdminOptions
{
    public string Username { get; set; } = "admin";
    public string Email { get; set; } = "";
    public string Password { get; set; } = "";
}
