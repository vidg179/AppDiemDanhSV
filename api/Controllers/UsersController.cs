using BaKhi_API.Data;
using BaKhi_API.Dtos;
using BaKhi_API.Infrastructure;
using BaKhi_API.Models;
using BaKhi_API.Services;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BaKhi_API.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public class UsersController(FirestoreContext ctx, FaceService face) : ControllerBase
{
    [HttpGet("me")]
    public async Task<UserDto> Me() => UserDto.From(await LoadAsync(User.UserId()));

    [HttpPut("me")]
    public async Task<UserDto> UpdateMe(UpdateProfileRequest req)
    {
        var user = await LoadAsync(User.UserId());
        user.FullName = req.FullName.Trim();
        user.Phone = req.Phone;
        await ctx.Users.Document(user.Id).UpdateAsync(new Dictionary<string, object?>
        {
            [nameof(AppUser.FullName)] = user.FullName,
            [nameof(AppUser.Phone)] = user.Phone,
        });
        return UserDto.From(user);
    }

    [HttpPost("me/change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
    {
        var user = await LoadAsync(User.UserId());
        if (user.PasswordHash is not null &&
            (req.CurrentPassword is null || !BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash)))
            throw AppException.BadRequest("Mật khẩu hiện tại không đúng");

        await ctx.Users.Document(user.Id).UpdateAsync(nameof(AppUser.PasswordHash), BCrypt.Net.BCrypt.HashPassword(req.NewPassword));
        return Ok(new { message = "Đổi mật khẩu thành công" });
    }

    /// <summary>Đăng ký (hoặc đăng ký lại) khuôn mặt: 1-5 vector, nên chụp 3 góc. Cần xác nhận mật khẩu.</summary>
    [HttpPost("me/face")]
    public async Task<FaceRegisteredResponse> RegisterFace(RegisterFaceRequest req)
    {
        var user = await LoadAsync(User.UserId());
        if (user.PasswordHash is not null &&
            (req.Password is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash)))
            throw AppException.BadRequest("Mật khẩu xác nhận không đúng");

        var profile = await face.RegisterAsync(user, req.Embeddings);
        return new FaceRegisteredResponse(profile.Samples.Count, profile.Dimension, profile.UpdatedAt);
    }

    /// <summary>Thử so khớp khuôn mặt với mẫu đã đăng ký (để test/chỉnh ngưỡng), trả về độ giống.</summary>
    [HttpPost("me/face/verify")]
    public Task<FaceVerifyResponse> VerifyFace(FaceEmbeddingRequest req) =>
        face.VerifyAsync(User.UserId(), req.Embedding, countFailures: false);

    [HttpDelete("me/face")]
    public async Task<IActionResult> RemoveMyFace()
    {
        await face.RemoveAsync((await LoadAsync(User.UserId())).Id);
        return NoContent();
    }

    /// <summary>Admin xóa khuôn mặt của 1 user để họ đăng ký lại.</summary>
    [HttpDelete("{id}/face")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<IActionResult> RemoveFace(string id)
    {
        await face.RemoveAsync((await LoadAsync(id)).Id);
        return NoContent();
    }

    /// <summary>Danh sách người dùng. Lọc theo role (admin/teacher/student) và từ khóa.</summary>
    [HttpGet]
    [Authorize(Roles = AppRoles.AdminOrTeacher)]
    public async Task<List<UserDto>> List([FromQuery] string? role, [FromQuery] string? search)
    {
        Query query = ctx.Users;
        if (!string.IsNullOrWhiteSpace(role)) query = query.WhereEqualTo(nameof(AppUser.Role), role);
        var users = await FirestoreContext.ListAsync<AppUser>(query);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim();
            users = users.Where(u =>
                u.FullName.Contains(s, StringComparison.OrdinalIgnoreCase) ||
                u.Username.Contains(s, StringComparison.OrdinalIgnoreCase) ||
                u.Email.Contains(s, StringComparison.OrdinalIgnoreCase) ||
                (u.StudentCode?.Contains(s, StringComparison.OrdinalIgnoreCase) ?? false)).ToList();
        }
        return users.OrderBy(u => u.FullName).Select(UserDto.From).ToList();
    }

    [HttpGet("{id}")]
    [Authorize(Roles = AppRoles.AdminOrTeacher)]
    public async Task<UserDto> Get(string id) => UserDto.From(await LoadAsync(id));

    [HttpPost]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ActionResult<UserDto>> Create(CreateUserRequest req)
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
            Role = req.Role,
            StudentCode = req.StudentCode,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
            EmailVerified = true,
        };
        user.Id = (await ctx.Users.AddAsync(user)).Id;
        return CreatedAtAction(nameof(Get), new { id = user.Id }, UserDto.From(user));
    }

    [HttpPut("{id}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<UserDto> Update(string id, UpdateUserRequest req)
    {
        var user = await LoadAsync(id);
        var email = req.Email.Trim().ToLowerInvariant();
        if (email != user.Email && await ctx.FindUserByEmailAsync(email) is not null)
            throw AppException.Conflict("Email đã được sử dụng");
        if (id == User.UserId() && req.Role != AppRoles.Admin)
            throw AppException.BadRequest("Không thể tự bỏ quyền admin của chính mình");

        user.Email = email;
        user.FullName = req.FullName.Trim();
        user.Role = req.Role;
        user.Phone = req.Phone;
        user.StudentCode = req.StudentCode;
        if (!string.IsNullOrEmpty(req.NewPassword))
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);

        await ctx.Users.Document(id).SetAsync(user);
        return UserDto.From(user);
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<IActionResult> Delete(string id)
    {
        if (id == User.UserId()) throw AppException.BadRequest("Không thể tự xóa chính mình");
        var user = await LoadAsync(id);

        var teaching = await ctx.Classes.WhereEqualTo(nameof(ClassRoom.TeacherId), id).Limit(1).GetSnapshotAsync();
        if (teaching.Count > 0)
            throw AppException.Conflict("Giảng viên đang phụ trách lớp, hãy đổi giảng viên của lớp trước");

        var enrolled = await ctx.Classes.WhereArrayContains(nameof(ClassRoom.StudentIds), id).GetSnapshotAsync();
        foreach (var doc in enrolled.Documents)
            await doc.Reference.UpdateAsync(nameof(ClassRoom.StudentIds), FieldValue.ArrayRemove(id));
        await ctx.DeleteWhereAsync(ctx.Attendances, nameof(AttendanceRecord.StudentId), id);
        await ctx.DeleteAbsenceRequestsWhereAsync(nameof(AbsenceRequest.StudentId), id);
        await ctx.FaceProfiles.Document(id).DeleteAsync();

        await ctx.Users.Document(user.Id).DeleteAsync();
        return NoContent();
    }

    private async Task<AppUser> LoadAsync(string id) =>
        await FirestoreContext.GetAsync<AppUser>(ctx.Users, id) ?? throw AppException.NotFound("Không tìm thấy người dùng");
}
