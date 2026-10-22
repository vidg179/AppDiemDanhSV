using System.Text;
using BaKhi_API.Data;
using BaKhi_API.Infrastructure;
using BaKhi_API.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

builder.Services.Configure<JwtOptions>(config.GetSection("Jwt"));
builder.Services.Configure<OtpOptions>(config.GetSection("Otp"));
builder.Services.Configure<SmtpOptions>(config.GetSection("Smtp"));
builder.Services.Configure<TwilioOptions>(config.GetSection("Twilio"));
builder.Services.Configure<GoogleAuthOptions>(config.GetSection("Google"));
builder.Services.Configure<AttendanceOptions>(config.GetSection("Attendance"));
builder.Services.Configure<AbsenceOptions>(config.GetSection("AbsenceRequest"));
builder.Services.Configure<FaceOptions>(config.GetSection("Face"));
builder.Services.Configure<SeedAdminOptions>(config.GetSection("SeedAdmin"));
builder.Services.Configure<DemoOptions>(config.GetSection("Demo"));

var jwt = config.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (jwt.Key.Length < 32)
    throw new InvalidOperationException("Jwt:Key phải dài ít nhất 32 ký tự (appsettings hoặc biến môi trường Jwt__Key).");

builder.Services.AddSingleton(_ => FirestoreContext.Create(config, builder.Environment.ContentRootPath));
builder.Services.AddSingleton<FirestoreContext>();
builder.Services.AddSingleton<JwtService>();
builder.Services.AddHttpClient<NotificationService>();
builder.Services.AddScoped<OtpService>();
builder.Services.AddScoped<FaceService>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            NameClaimType = "name",
            RoleClaimType = "role",
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Điểm danh HUTECH - API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Dán token nhận được từ /api/auth/verify-otp (không cần gõ chữ Bearer)",
    });
    c.AddSecurityRequirement(doc => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", doc)] = [],
    });
});

var app = builder.Build();

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (AppException ex)
    {
        context.Response.StatusCode = ex.StatusCode;
        await context.Response.WriteAsJsonAsync(new { message = ex.Message });
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Lỗi không xử lý được");
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await context.Response.WriteAsJsonAsync(new { message = "Lỗi máy chủ" });
    }
});

app.UseSwagger();
app.UseSwaggerUI(c => c.DocumentTitle = "Điểm danh HUTECH API");
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

await app.Services.GetRequiredService<FirestoreContext>()
    .SeedAdminAsync(app.Services.GetRequiredService<IOptions<SeedAdminOptions>>().Value, app.Logger);

await app.Services.GetRequiredService<FirestoreContext>()
    .SeedDemoAsync(app.Services.GetRequiredService<IOptions<DemoOptions>>().Value, app.Logger);

app.Run();
