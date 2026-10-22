using System.Security.Cryptography;
using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BaKhi_API.Controllers;

[ApiController]
[Authorize]
public class SessionsController(FirestoreContext ctx) : ControllerBase
{
    [HttpGet("api/classes/{classId}/sessions")]
    public async Task<List<SessionDto>> List(string classId)
    {
        await ctx.GetClassAsync(classId, User, manage: false);
        var sessions = await FirestoreContext.ListAsync<ClassSession>(
            ctx.Sessions.WhereEqualTo(nameof(ClassSession.ClassId), classId));
        var canManage = User.Role() != AppRoles.Student;
        return sessions.OrderBy(s => s.StartTime).Select(s => SessionDto.From(s, canManage)).ToList();
    }

    /// <summary>Tạo buổi học. Nếu gửi latitude/longitude thì sinh viên phải ở trong bán kính radiusMeters mới điểm danh được.</summary>
    [HttpPost("api/classes/{classId}/sessions")]
    public async Task<ActionResult<SessionDto>> Create(string classId, SaveSessionRequest req)
    {
        await ctx.GetClassAsync(classId, User, manage: true);
        var session = new ClassSession { ClassId = classId };
        Apply(session, req);
        session.Id = (await ctx.Sessions.AddAsync(session)).Id;
        return CreatedAtAction(nameof(Get), new { id = session.Id }, SessionDto.From(session, true));
    }

    [HttpGet("api/sessions/{id}")]
    public async Task<SessionDto> Get(string id)
    {
        var session = await ctx.GetSessionAsync(id);
        await ctx.GetClassAsync(session.ClassId, User, manage: false);
        return SessionDto.From(session, User.Role() != AppRoles.Student);
    }

    [HttpPut("api/sessions/{id}")]
    public async Task<SessionDto> Update(string id, SaveSessionRequest req)
    {
        var session = await ctx.GetSessionAsync(id);
        await ctx.GetClassAsync(session.ClassId, User, manage: true);
        Apply(session, req);
        await ctx.Sessions.Document(id).SetAsync(session);
        return SessionDto.From(session, true);
    }

    [HttpDelete("api/sessions/{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var session = await ctx.GetSessionAsync(id);
        await ctx.GetClassAsync(session.ClassId, User, manage: true);
        await ctx.DeleteAbsenceRequestsWhereAsync(nameof(AbsenceRequest.SessionId), id);
        await ctx.DeleteWhereAsync(ctx.Attendances, nameof(AttendanceRecord.SessionId), id);
        await ctx.Sessions.Document(id).DeleteAsync();
        return NoContent();
    }

    /// <summary>Tạo mã QR mới cho buổi học (mã cũ hết hiệu lực). Flutter vẽ QR từ chuỗi qrToken.</summary>
    [HttpPost("api/sessions/{id}/qr")]
    public async Task<QrResponse> GenerateQr(string id, GenerateQrRequest? req)
    {
        var session = await ctx.GetSessionAsync(id);
        await ctx.GetClassAsync(session.ClassId, User, manage: true);

        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(12));
        var expires = DateTime.UtcNow.AddMinutes(req?.ValidMinutes ?? 5);
        await ctx.Sessions.Document(id).UpdateAsync(new Dictionary<string, object>
        {
            [nameof(ClassSession.QrToken)] = token,
            [nameof(ClassSession.QrExpiresAt)] = expires,
        });
        return new QrResponse(id, token, expires);
    }

    /// <summary>
    /// Danh sách điểm danh của buổi học: mọi sinh viên trong lớp kèm trạng thái, tọa độ lúc điểm danh
    /// và khoảng cách tới lớp (để vẽ bản đồ: tâm = latitude/longitude của buổi học, bán kính = radiusMeters).
    /// </summary>
    [HttpGet("api/sessions/{id}/attendance")]
    public async Task<List<RosterItemDto>> Roster(string id)
    {
        var session = await ctx.GetSessionAsync(id);
        var cls = await ctx.GetClassAsync(session.ClassId, User, manage: true);
        var students = await ctx.GetUsersByIdsAsync(cls.StudentIds);
        var records = (await FirestoreContext.ListAsync<AttendanceRecord>(
                ctx.Attendances.WhereEqualTo(nameof(AttendanceRecord.SessionId), id)))
            .ToDictionary(r => r.StudentId);
        var defaultStatus = session.EndTime < DateTime.UtcNow ? AttendanceStatus.Absent : AttendanceStatus.Pending;

        return students.OrderBy(s => s.FullName).Select(s =>
        {
            var r = records.GetValueOrDefault(s.Id);
            double? distance = session is { Latitude: { } lat, Longitude: { } lng } && r is { Latitude: { } rLat, Longitude: { } rLng }
                ? Math.Round(Geo.DistanceMeters(lat, lng, rLat, rLng), 1)
                : null;
            return new RosterItemDto(s.Id, s.FullName, s.StudentCode, r?.Id, r?.Status ?? defaultStatus,
                r?.Method, r?.CheckInTime, r?.Note, r?.Latitude, r?.Longitude, distance, r?.FaceVerified ?? false);
        }).ToList();
    }

    private static void Apply(ClassSession session, SaveSessionRequest req)
    {
        if (req.EndTime <= req.StartTime) throw AppException.BadRequest("Giờ kết thúc phải sau giờ bắt đầu");
        if (req.Latitude.HasValue != req.Longitude.HasValue)
            throw AppException.BadRequest("Phải gửi cả latitude và longitude");

        session.Title = req.Title.Trim();
        session.StartTime = req.StartTime.UtcDateTime;
        session.EndTime = req.EndTime.UtcDateTime;
        session.Latitude = req.Latitude;
        session.Longitude = req.Longitude;
        session.RadiusMeters = req.RadiusMeters ?? 100;
        session.RequireFace = req.RequireFace;
    }
}
