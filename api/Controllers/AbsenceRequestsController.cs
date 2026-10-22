using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using BaKhi_API.Services;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace BaKhi_API.Controllers;

/// <summary>Đơn xin phép vắng kèm minh chứng: SV gửi → GV/admin duyệt → điểm danh tự chuyển "có phép".</summary>
[ApiController]
[Route("api/absence-requests")]
[Authorize]
public class AbsenceRequestsController(
    FirestoreContext ctx,
    NotificationService notify,
    IOptions<AbsenceOptions> options) : ControllerBase
{
    private AbsenceOptions O => options.Value;

    /// <summary>Sinh viên gửi đơn xin phép cho 1 buổi học (multipart/form-data, đính kèm ảnh/PDF minh chứng).</summary>
    [HttpPost]
    [Authorize(Roles = AppRoles.Student)]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<AbsenceRequestDto>> Create([FromForm] CreateAbsenceRequestForm form)
    {
        var uid = User.UserId();
        var session = await ctx.GetSessionAsync(form.SessionId);
        var cls = await ctx.GetClassAsync(session.ClassId, User, manage: false);

        if (DateTime.UtcNow > session.EndTime.AddDays(O.MaxDaysAfterSession))
            throw AppException.BadRequest($"Đã quá hạn xin phép (tối đa {O.MaxDaysAfterSession} ngày sau buổi học)");

        var mine = await FirestoreContext.ListAsync<AbsenceRequest>(
            ctx.AbsenceRequests.WhereEqualTo(nameof(AbsenceRequest.StudentId), uid));
        if (mine.Any(r => r.SessionId == session.Id && r.Status != AbsenceStatus.Rejected))
            throw AppException.Conflict("Bạn đã gửi đơn xin phép cho buổi này rồi");

        var attendance = await FirestoreContext.GetAsync<AttendanceRecord>(
            ctx.Attendances, AttendanceRecord.MakeId(session.Id, uid));
        if (attendance?.Status is AttendanceStatus.Present or AttendanceStatus.Late)
            throw AppException.Conflict("Bạn đã có mặt ở buổi này, không cần xin phép");

        var files = await ReadFilesAsync(form.Files ?? [], 0);
        var student = await FirestoreContext.GetAsync<AppUser>(ctx.Users, uid)
                      ?? throw AppException.NotFound("Không tìm thấy người dùng");

        var docRef = ctx.AbsenceRequests.Document();
        var request = new AbsenceRequest
        {
            Id = docRef.Id,
            StudentId = uid,
            StudentName = student.FullName,
            StudentCode = student.StudentCode,
            ClassId = cls.Id,
            ClassName = cls.Name,
            SessionId = session.Id,
            SessionTitle = session.Title,
            SessionStart = session.StartTime,
            Category = form.Category ?? "other",
            Reason = form.Reason.Trim(),
        };

        var batch = ctx.Db.StartBatch();
        AddFilesToBatch(batch, request, files);
        batch.Create(docRef, request);
        await batch.CommitAsync();

        if (cls.TeacherId is not null)
        {
            var teacher = await FirestoreContext.GetAsync<AppUser>(ctx.Users, cls.TeacherId);
            await notify.TrySendEmailAsync(teacher?.Email, $"[HUTECH] Đơn xin phép mới - {cls.Name}",
                $"{student.FullName} ({student.StudentCode}) xin phép vắng buổi \"{session.Title}\".\n" +
                $"Lý do: {request.Reason}\nMinh chứng: {request.Evidence.Count} file.\nVào app Điểm danh HUTECH để duyệt đơn.");
        }

        return CreatedAtAction(nameof(Get), new { id = request.Id }, AbsenceRequestDto.From(request));
    }

    /// <summary>Bổ sung minh chứng cho đơn đang chờ duyệt.</summary>
    [HttpPost("{id}/evidence")]
    [Authorize(Roles = AppRoles.Student)]
    [Consumes("multipart/form-data")]
    public async Task<AbsenceRequestDto> AddEvidence(string id, [FromForm] AddEvidenceForm form)
    {
        var request = await LoadAsync(id);
        if (request.StudentId != User.UserId()) throw AppException.Forbidden("Không phải đơn của bạn");
        if (request.Status != AbsenceStatus.Pending) throw AppException.Conflict("Đơn đã được xử lý, không thể bổ sung");

        var files = await ReadFilesAsync(form.Files, request.Evidence.Count);
        var batch = ctx.Db.StartBatch();
        AddFilesToBatch(batch, request, files);
        batch.Update(ctx.AbsenceRequests.Document(id), nameof(AbsenceRequest.Evidence), request.Evidence);
        await batch.CommitAsync();
        return AbsenceRequestDto.From(request);
    }

    /// <summary>SV: đơn của mình. GV: đơn của các lớp mình dạy. Admin: tất cả. Lọc theo status (pending/approved/rejected) và classId.</summary>
    [HttpGet]
    public async Task<List<AbsenceRequestDto>> List([FromQuery] string? status, [FromQuery] string? classId)
    {
        var uid = User.UserId();
        List<AbsenceRequest> requests;
        switch (User.Role())
        {
            case AppRoles.Student:
                requests = await FirestoreContext.ListAsync<AbsenceRequest>(
                    ctx.AbsenceRequests.WhereEqualTo(nameof(AbsenceRequest.StudentId), uid));
                if (!string.IsNullOrWhiteSpace(classId)) requests = requests.Where(r => r.ClassId == classId).ToList();
                break;

            case AppRoles.Teacher:
                var classIds = (await FirestoreContext.ListAsync<ClassRoom>(
                        ctx.Classes.WhereEqualTo(nameof(ClassRoom.TeacherId), uid)))
                    .Select(c => c.Id).ToList();
                if (!string.IsNullOrWhiteSpace(classId))
                {
                    if (!classIds.Contains(classId)) throw AppException.Forbidden("Bạn không dạy lớp này");
                    classIds = [classId];
                }
                requests = [];
                foreach (var chunk in classIds.Chunk(30))
                    requests.AddRange(await FirestoreContext.ListAsync<AbsenceRequest>(
                        ctx.AbsenceRequests.WhereIn(nameof(AbsenceRequest.ClassId), chunk)));
                break;

            default:
                Query query = ctx.AbsenceRequests;
                if (!string.IsNullOrWhiteSpace(classId))
                    query = query.WhereEqualTo(nameof(AbsenceRequest.ClassId), classId);
                requests = await FirestoreContext.ListAsync<AbsenceRequest>(query);
                break;
        }

        if (!string.IsNullOrWhiteSpace(status)) requests = requests.Where(r => r.Status == status).ToList();
        return requests.OrderByDescending(r => r.CreatedAt).Select(AbsenceRequestDto.From).ToList();
    }

    [HttpGet("{id}")]
    public async Task<AbsenceRequestDto> Get(string id) => AbsenceRequestDto.From(await LoadForReadAsync(id));

    /// <summary>Tải file minh chứng (ảnh hiển thị bằng Image.network kèm header Authorization).</summary>
    [HttpGet("{id}/evidence/{fileId}")]
    public async Task<IActionResult> GetEvidence(string id, string fileId)
    {
        var request = await LoadForReadAsync(id);
        var info = request.Evidence.FirstOrDefault(e => e.Id == fileId)
                   ?? throw AppException.NotFound("Không tìm thấy file minh chứng");
        var file = await FirestoreContext.GetAsync<EvidenceFile>(ctx.EvidenceFiles, fileId)
                   ?? throw AppException.NotFound("Không tìm thấy file minh chứng");

        Response.Headers.XContentTypeOptions = "nosniff";
        return File(file.Data, info.ContentType);
    }

    /// <summary>GV của lớp / admin duyệt đơn. Duyệt → điểm danh buổi đó chuyển thành "excused" (có phép).</summary>
    [HttpPost("{id}/review")]
    [Authorize(Roles = AppRoles.AdminOrTeacher)]
    public async Task<AbsenceRequestDto> Review(string id, ReviewAbsenceRequest req)
    {
        var request = await LoadAsync(id);
        await ctx.GetClassAsync(request.ClassId, User, manage: true);
        if (request.Status != AbsenceStatus.Pending) throw AppException.Conflict("Đơn đã được xử lý trước đó");

        request.Status = req.Status;
        request.ReviewerId = User.UserId();
        request.ReviewerName = User.Identity?.Name;
        request.ReviewNote = req.Note;
        request.ReviewedAt = DateTime.UtcNow;

        var batch = ctx.Db.StartBatch();
        batch.Set(ctx.AbsenceRequests.Document(id), request);
        if (req.Status == AbsenceStatus.Approved)
        {
            var attendanceId = AttendanceRecord.MakeId(request.SessionId, request.StudentId);
            var existing = await FirestoreContext.GetAsync<AttendanceRecord>(ctx.Attendances, attendanceId);
            if (existing?.Status is not (AttendanceStatus.Present or AttendanceStatus.Late))
            {
                batch.Set(ctx.Attendances.Document(attendanceId), new AttendanceRecord
                {
                    SessionId = request.SessionId,
                    ClassId = request.ClassId,
                    StudentId = request.StudentId,
                    Status = AttendanceStatus.Excused,
                    Method = AttendanceMethods.AbsenceRequest,
                    Note = $"Có phép: {Truncate(request.Reason, 200)}",
                });
            }
        }
        await batch.CommitAsync();

        var student = await FirestoreContext.GetAsync<AppUser>(ctx.Users, request.StudentId);
        var verdict = req.Status == AbsenceStatus.Approved ? "ĐƯỢC DUYỆT" : "BỊ TỪ CHỐI";
        await notify.TrySendEmailAsync(student?.Email, $"[HUTECH] Đơn xin phép {verdict.ToLowerInvariant()}",
            $"Đơn xin phép buổi \"{request.SessionTitle}\" lớp {request.ClassName} đã {verdict}." +
            (string.IsNullOrWhiteSpace(req.Note) ? "" : $"\nGhi chú của giảng viên: {req.Note}"));

        return AbsenceRequestDto.From(request);
    }

    /// <summary>SV hủy đơn đang chờ duyệt; admin xóa được mọi đơn.</summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var request = await LoadAsync(id);
        if (User.Role() != AppRoles.Admin)
        {
            if (request.StudentId != User.UserId()) throw AppException.Forbidden("Không phải đơn của bạn");
            if (request.Status != AbsenceStatus.Pending) throw AppException.Conflict("Chỉ hủy được đơn đang chờ duyệt");
        }
        await ctx.DeleteAbsenceRequestAsync(request);
        return NoContent();
    }

    private async Task<AbsenceRequest> LoadAsync(string id) =>
        await FirestoreContext.GetAsync<AbsenceRequest>(ctx.AbsenceRequests, id)
        ?? throw AppException.NotFound("Không tìm thấy đơn xin phép");

    private async Task<AbsenceRequest> LoadForReadAsync(string id)
    {
        var request = await LoadAsync(id);
        if (User.Role() == AppRoles.Student)
        {
            if (request.StudentId != User.UserId()) throw AppException.Forbidden("Không phải đơn của bạn");
        }
        else
        {
            await ctx.GetClassAsync(request.ClassId, User, manage: true);
        }
        return request;
    }

    private async Task<List<(EvidenceInfo Info, byte[] Data)>> ReadFilesAsync(List<IFormFile> files, int existingCount)
    {
        if (files.Count + existingCount > O.MaxFiles)
            throw AppException.BadRequest($"Tối đa {O.MaxFiles} file minh chứng cho mỗi đơn");

        var result = new List<(EvidenceInfo, byte[])>();
        foreach (var file in files)
        {
            if (file.Length == 0) throw AppException.BadRequest($"File {file.FileName} rỗng");
            if (file.Length > O.MaxFileSizeKb * 1024L)
                throw AppException.BadRequest(
                    $"File {file.FileName} quá lớn (tối đa {O.MaxFileSizeKb} KB), hãy nén ảnh trước khi gửi");

            using var stream = new MemoryStream();
            await file.CopyToAsync(stream);
            var data = stream.ToArray();
            var contentType = DetectContentType(data)
                              ?? throw AppException.BadRequest($"File {file.FileName}: chỉ nhận ảnh JPG/PNG/WEBP hoặc PDF");

            result.Add((new EvidenceInfo
            {
                Id = ctx.EvidenceFiles.Document().Id,
                FileName = Truncate(Path.GetFileName(file.FileName), 100),
                ContentType = contentType,
                Size = data.Length,
            }, data));
        }
        return result;
    }

    private void AddFilesToBatch(WriteBatch batch, AbsenceRequest request, List<(EvidenceInfo Info, byte[] Data)> files)
    {
        foreach (var (info, data) in files)
        {
            batch.Create(ctx.EvidenceFiles.Document(info.Id), new EvidenceFile { RequestId = request.Id, Data = data });
            request.Evidence.Add(info);
        }
    }

    // Kiểm tra chữ ký đầu file thay vì tin Content-Type do client gửi.
    private static string? DetectContentType(byte[] d) => d switch
    {
        [0xFF, 0xD8, 0xFF, ..] => "image/jpeg",
        [0x89, 0x50, 0x4E, 0x47, ..] => "image/png",
        [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ..] => "image/webp",
        [0x25, 0x50, 0x44, 0x46, ..] => "application/pdf",
        _ => null,
    };

    private static string Truncate(string s, int max) => s.Length <= max ? s : s[..max];
}
