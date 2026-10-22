using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BaKhi_API.Controllers;

[ApiController]
[Route("api/classes")]
[Authorize]
public class ClassesController(FirestoreContext ctx) : ControllerBase
{
    /// <summary>Admin: tất cả lớp. Giảng viên: lớp mình dạy. Sinh viên: lớp mình học.</summary>
    [HttpGet]
    public async Task<List<ClassDto>> List()
    {
        var uid = User.UserId();
        Query query = User.Role() switch
        {
            AppRoles.Admin => ctx.Classes,
            AppRoles.Teacher => ctx.Classes.WhereEqualTo(nameof(ClassRoom.TeacherId), uid),
            _ => ctx.Classes.WhereArrayContains(nameof(ClassRoom.StudentIds), uid),
        };
        var classes = await FirestoreContext.ListAsync<ClassRoom>(query);
        var teachers = (await ctx.GetUsersByIdsAsync(classes.Select(c => c.TeacherId!).Where(t => t is not null)))
            .ToDictionary(t => t.Id);
        return classes.OrderBy(c => c.Code)
            .Select(c => ToDto(c, c.TeacherId is null ? null : teachers.GetValueOrDefault(c.TeacherId)))
            .ToList();
    }

    [HttpGet("{id}")]
    public async Task<ClassDto> Get(string id)
    {
        var cls = await ctx.GetClassAsync(id, User, manage: false);
        return ToDto(cls, await LoadTeacherAsync(cls.TeacherId));
    }

    [HttpPost]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ActionResult<ClassDto>> Create(SaveClassRequest req)
    {
        await EnsureCodeUniqueAsync(req.Code, null);
        var teacher = await LoadTeacherAsync(req.TeacherId, validate: true);
        var cls = new ClassRoom
        {
            Code = req.Code.Trim(),
            Name = req.Name.Trim(),
            Subject = req.Subject,
            Room = req.Room,
            TeacherId = teacher?.Id,
        };
        cls.Id = (await ctx.Classes.AddAsync(cls)).Id;
        return CreatedAtAction(nameof(Get), new { id = cls.Id }, ToDto(cls, teacher));
    }

    [HttpPut("{id}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ClassDto> Update(string id, SaveClassRequest req)
    {
        var cls = await ctx.GetClassAsync(id, User, manage: true);
        await EnsureCodeUniqueAsync(req.Code, id);
        var teacher = await LoadTeacherAsync(req.TeacherId, validate: true);

        cls.Code = req.Code.Trim();
        cls.Name = req.Name.Trim();
        cls.Subject = req.Subject;
        cls.Room = req.Room;
        cls.TeacherId = teacher?.Id;
        await ctx.Classes.Document(id).SetAsync(cls);
        return ToDto(cls, teacher);
    }

    /// <summary>Xóa lớp cùng toàn bộ buổi học, điểm danh và đơn xin phép của lớp.</summary>
    [HttpDelete("{id}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<IActionResult> Delete(string id)
    {
        await ctx.GetClassAsync(id, User, manage: true);
        await ctx.DeleteAbsenceRequestsWhereAsync(nameof(AbsenceRequest.ClassId), id);
        await ctx.DeleteWhereAsync(ctx.Attendances, nameof(AttendanceRecord.ClassId), id);
        await ctx.DeleteWhereAsync(ctx.Sessions, nameof(ClassSession.ClassId), id);
        await ctx.Classes.Document(id).DeleteAsync();
        return NoContent();
    }

    [HttpGet("{id}/students")]
    public async Task<List<UserDto>> Students(string id)
    {
        var cls = await ctx.GetClassAsync(id, User, manage: true);
        var students = await ctx.GetUsersByIdsAsync(cls.StudentIds);
        return students.OrderBy(s => s.FullName).Select(UserDto.From).ToList();
    }

    [HttpPost("{id}/students")]
    public async Task<ClassDto> AddStudents(string id, AddStudentsRequest req)
    {
        var cls = await ctx.GetClassAsync(id, User, manage: true);
        var users = await ctx.GetUsersByIdsAsync(req.StudentIds);
        var invalid = req.StudentIds.Distinct().Except(users.Where(u => u.Role == AppRoles.Student).Select(u => u.Id)).ToList();
        if (invalid.Count > 0)
            throw AppException.BadRequest($"Không phải sinh viên hợp lệ: {string.Join(", ", invalid)}");

        await ctx.Classes.Document(id).UpdateAsync(nameof(ClassRoom.StudentIds),
            FieldValue.ArrayUnion(req.StudentIds.Distinct().Cast<object>().ToArray()));
        cls.StudentIds = cls.StudentIds.Union(req.StudentIds).ToList();
        return ToDto(cls, await LoadTeacherAsync(cls.TeacherId));
    }

    [HttpDelete("{id}/students/{studentId}")]
    public async Task<IActionResult> RemoveStudent(string id, string studentId)
    {
        await ctx.GetClassAsync(id, User, manage: true);
        await ctx.Classes.Document(id).UpdateAsync(nameof(ClassRoom.StudentIds), FieldValue.ArrayRemove(studentId));
        return NoContent();
    }

    private async Task EnsureCodeUniqueAsync(string code, string? currentId)
    {
        var existing = await FirestoreContext.ListAsync<ClassRoom>(
            ctx.Classes.WhereEqualTo(nameof(ClassRoom.Code), code.Trim()).Limit(2));
        if (existing.Any(c => c.Id != currentId)) throw AppException.Conflict("Mã lớp đã tồn tại");
    }

    private async Task<AppUser?> LoadTeacherAsync(string? teacherId, bool validate = false)
    {
        if (string.IsNullOrWhiteSpace(teacherId)) return null;
        var teacher = await FirestoreContext.GetAsync<AppUser>(ctx.Users, teacherId);
        if (validate && teacher?.Role != AppRoles.Teacher)
            throw AppException.BadRequest("TeacherId không phải giảng viên hợp lệ");
        return teacher;
    }

    private static ClassDto ToDto(ClassRoom c, AppUser? teacher) =>
        new(c.Id, c.Code, c.Name, c.Subject, c.Room, c.TeacherId, teacher?.FullName, c.StudentIds.Count, c.CreatedAt);
}
