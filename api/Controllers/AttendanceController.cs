using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using BaKhi_API.Services;
using Google.Cloud.Firestore;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace BaKhi_API.Controllers;

[ApiController]
[Authorize]
public class AttendanceController(FirestoreContext ctx, FaceService face, IOptions<AttendanceOptions> options) : ControllerBase
{
    /// <summary>
    /// Sinh viên quét QR để điểm danh. Gửi kèm GPS nếu buổi học có vị trí,
    /// và faceEmbedding nếu buổi học bật requireFace (chống điểm danh hộ).
    /// </summary>
    [HttpPost("api/attendance/checkin")]
    [Authorize(Roles = AppRoles.Student)]
    public async Task<AttendanceDto> CheckIn(CheckInRequest req)
    {
        var uid = User.UserId();
        var session = (await FirestoreContext.ListAsync<ClassSession>(
                ctx.Sessions.WhereEqualTo(nameof(ClassSession.QrToken), req.QrToken.Trim()).Limit(1)))
            .FirstOrDefault() ?? throw AppException.BadRequest("Mã QR không hợp lệ");

        var now = DateTime.UtcNow;
        if (session.QrExpiresAt is null || now > session.QrExpiresAt)
            throw AppException.BadRequest("Mã QR đã hết hạn, nhờ giảng viên tạo mã mới");

        var cls = await FirestoreContext.GetAsync<ClassRoom>(ctx.Classes, session.ClassId)
                  ?? throw AppException.NotFound("Không tìm thấy lớp");
        if (!cls.StudentIds.Contains(uid)) throw AppException.Forbidden("Bạn không thuộc lớp này");

        if (session is { Latitude: { } lat, Longitude: { } lng })
        {
            if (req.Latitude is null || req.Longitude is null)
                throw AppException.BadRequest("Buổi học yêu cầu gửi vị trí GPS");
            var distance = Geo.DistanceMeters(lat, lng, req.Latitude.Value, req.Longitude.Value);
            if (distance > session.RadiusMeters)
                throw AppException.BadRequest($"Bạn đang cách lớp {distance:0} m (cho phép {session.RadiusMeters:0} m)");
        }

        if (session.RequireFace && req.FaceEmbedding is not { Count: > 0 })
            throw AppException.BadRequest("Buổi học yêu cầu xác thực khuôn mặt");
        var faceVerified = false;
        if (req.FaceEmbedding is { Count: > 0 })
        {
            var result = await face.VerifyAsync(uid, req.FaceEmbedding, countFailures: true);
            if (!result.Match) throw AppException.BadRequest("Khuôn mặt không khớp với chủ tài khoản");
            faceVerified = true;
        }

        var record = new AttendanceRecord
        {
            SessionId = session.Id,
            ClassId = session.ClassId,
            StudentId = uid,
            Status = now <= session.StartTime.AddMinutes(options.Value.LateAfterMinutes)
                ? AttendanceStatus.Present
                : AttendanceStatus.Late,
            Method = AttendanceMethods.Qr,
            CheckInTime = now,
            Latitude = req.Latitude,
            Longitude = req.Longitude,
            FaceVerified = faceVerified,
        };
        record.Id = AttendanceRecord.MakeId(session.Id, uid);
        try
        {
            await ctx.Attendances.Document(record.Id).CreateAsync(record);
        }
        catch (RpcException ex) when (ex.StatusCode == Grpc.Core.StatusCode.AlreadyExists)
        {
            // Đã xin phép nhưng vẫn đến lớp → ghi đè thành có mặt.
            var existing = await FirestoreContext.GetAsync<AttendanceRecord>(ctx.Attendances, record.Id);
            if (existing?.Method != AttendanceMethods.AbsenceRequest)
                throw AppException.Conflict("Bạn đã được điểm danh buổi này rồi");
            await ctx.Attendances.Document(record.Id).SetAsync(record);
        }
        return AttendanceDto.From(record);
    }

    /// <summary>Lịch sử điểm danh của sinh viên đang đăng nhập (lọc theo lớp nếu có classId).</summary>
    [HttpGet("api/attendance/me")]
    [Authorize(Roles = AppRoles.Student)]
    public async Task<List<AttendanceDto>> Mine([FromQuery] string? classId)
    {
        var records = await FirestoreContext.ListAsync<AttendanceRecord>(
            ctx.Attendances.WhereEqualTo(nameof(AttendanceRecord.StudentId), User.UserId()));
        if (!string.IsNullOrWhiteSpace(classId)) records = records.Where(r => r.ClassId == classId).ToList();
        return records.OrderByDescending(r => r.CheckInTime ?? r.UpdatedAt).Select(AttendanceDto.From).ToList();
    }

    /// <summary>Giảng viên/admin điểm danh thủ công hoặc ghi đè trạng thái cho một sinh viên.</summary>
    [HttpPost("api/attendance")]
    public async Task<AttendanceDto> Mark(MarkAttendanceRequest req)
    {
        var session = await ctx.GetSessionAsync(req.SessionId);
        var cls = await ctx.GetClassAsync(session.ClassId, User, manage: true);
        if (!cls.StudentIds.Contains(req.StudentId)) throw AppException.BadRequest("Sinh viên không thuộc lớp này");

        var record = new AttendanceRecord
        {
            Id = AttendanceRecord.MakeId(session.Id, req.StudentId),
            SessionId = session.Id,
            ClassId = session.ClassId,
            StudentId = req.StudentId,
            Status = req.Status,
            Method = AttendanceMethods.Manual,
            CheckInTime = req.Status is AttendanceStatus.Present or AttendanceStatus.Late ? DateTime.UtcNow : null,
            Note = req.Note,
        };
        await ctx.Attendances.Document(record.Id).SetAsync(record);
        return AttendanceDto.From(record);
    }

    [HttpPut("api/attendance/{id}")]
    public async Task<AttendanceDto> Update(string id, UpdateAttendanceRequest req)
    {
        var record = await LoadAsync(id);
        await ctx.GetClassAsync(record.ClassId, User, manage: true);
        record.Status = req.Status;
        record.Note = req.Note;
        record.UpdatedAt = DateTime.UtcNow;
        await ctx.Attendances.Document(id).SetAsync(record);
        return AttendanceDto.From(record);
    }

    [HttpDelete("api/attendance/{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var record = await LoadAsync(id);
        await ctx.GetClassAsync(record.ClassId, User, manage: true);
        await ctx.Attendances.Document(id).DeleteAsync();
        return NoContent();
    }

    /// <summary>Thống kê chuyên cần theo lớp, đánh dấu sinh viên vắng vượt ngưỡng cảnh báo. Sinh viên chỉ thấy dòng của mình.</summary>
    [HttpGet("api/classes/{classId}/attendance/stats")]
    public async Task<ClassStatsDto> Stats(string classId)
    {
        var cls = await ctx.GetClassAsync(classId, User, manage: false);
        var now = DateTime.UtcNow;
        var heldSessionIds = (await FirestoreContext.ListAsync<ClassSession>(
                ctx.Sessions.WhereEqualTo(nameof(ClassSession.ClassId), classId)))
            .Where(s => s.StartTime <= now).Select(s => s.Id).ToHashSet();
        var records = (await FirestoreContext.ListAsync<AttendanceRecord>(
                ctx.Attendances.WhereEqualTo(nameof(AttendanceRecord.ClassId), classId)))
            .Where(r => heldSessionIds.Contains(r.SessionId))
            .ToLookup(r => r.StudentId);

        var studentIds = User.Role() == AppRoles.Student ? [User.UserId()] : cls.StudentIds;
        var students = await ctx.GetUsersByIdsAsync(studentIds);
        var total = heldSessionIds.Count;
        var threshold = options.Value.AbsentWarningPercent;

        var rows = students.OrderBy(s => s.FullName).Select(s =>
        {
            var mine = records[s.Id].ToList();
            int Count(string status) => mine.Count(r => r.Status == status);
            var present = Count(AttendanceStatus.Present);
            var late = Count(AttendanceStatus.Late);
            var excused = Count(AttendanceStatus.Excused);
            var absent = total - present - late - excused;
            var percent = total == 0 ? 0 : Math.Round(absent * 100.0 / total, 1);
            return new StudentStatsDto(s.Id, s.FullName, s.StudentCode, present, late, excused, absent, percent,
                percent >= threshold && absent > 0);
        }).ToList();

        return new ClassStatsDto(classId, total, threshold, rows);
    }

    private async Task<AttendanceRecord> LoadAsync(string id) =>
        await FirestoreContext.GetAsync<AttendanceRecord>(ctx.Attendances, id)
        ?? throw AppException.NotFound("Không tìm thấy bản ghi điểm danh");
}
