# BaKhi API: API điểm danh sinh viên

ASP.NET Core (.NET 10) + Firebase Firestore. Cả nhóm dùng chung 1 API; người làm Flutter chỉ cần **URL** và tài liệu dưới đây.

- **URL API (dùng trong Flutter): `https://42-96-2-9.sslip.io`**
- Tài liệu sống, thử API trực tiếp: https://42-96-2-9.sslip.io/swagger
- Mọi lỗi trả về dạng `{ "message": "..." }` kèm HTTP status (400, 401, 403, 404, 409, 429).
- Thời gian gửi lên dạng ISO 8601 **có múi giờ**, ví dụ `2026-10-22T07:30:00+07:00`. Server trả về giờ UTC (`...Z`), Flutter dùng `DateTime.parse(x).toLocal()`.

---

## 1. Cài đặt (người làm API)

### Bước 1: Tạo Firebase
1. Vào https://console.firebase.google.com → **Add project** (ví dụ `bakhi-diemdanh`).
2. Menu **Build → Firestore Database → Create database** → chọn region `asia-southeast1` → **production mode**.
3. **Project settings (bánh răng) → Service accounts → Generate new private key** → tải file JSON về.
4. Đổi tên file thành `firebase-key.json`, chép vào thư mục project này (cạnh `Program.cs`).
   File này là **bí mật**: đã nằm trong `.gitignore`, **không** gửi lên GitHub, không gửi vào nhóm chat.
5. Mở `appsettings.json`, điền `"Firebase": { "ProjectId": "<project-id của bạn>" }`.

### Bước 2: Chạy thử
Mở `BaKhi_API.slnx` bằng Visual Studio → F5 → trình duyệt mở Swagger.
Khi chạy Development, nếu database **chưa có admin**, server tự tạo tài khoản admin theo mục `SeedAdmin` trong `appsettings.Development.json` (copy từ `appsettings.Development.example.json` rồi đặt mật khẩu riêng). Đặt `Otp:ReturnCodeInResponse=true` thì mã OTP trả luôn trong field `devCode`, tiện test không cần email.

### Bước 3: Gửi OTP thật qua Gmail (khuyến nghị)
1. Bật xác minh 2 bước cho tài khoản Gmail → tạo **App password** (https://myaccount.google.com/apppasswords).
2. Điền vào cấu hình: `Smtp:User` = địa chỉ Gmail, `Smtp:Password` = app password 16 ký tự.
   Trên server thì điền `Smtp__User`, `Smtp__Password` trong `deploy/.env`.

SMS OTP dùng Twilio (`Twilio:AccountSid`, `AuthToken`, `From`). Chưa cấu hình thì mã OTP chỉ ghi ra log server.

### Bước 4: Deploy lên VPS
Thư mục `deploy/` có sẵn mọi thứ: Docker chạy API, **Caddy** tự lo HTTPS. Không cần mua tên miền: dùng `<IP-có-gạch-ngang>.sslip.io`.

1. Thuê VPS **Ubuntu 22.04/24.04**, tối thiểu 1 CPU, 1 GB RAM, có **IPv4**. Lấy **IP** và **mật khẩu root**.
2. Mở `deploy/.env` (đã có sẵn `Jwt__Key` ngẫu nhiên), điền `Smtp__User`, `Smtp__Password` để gửi OTP qua Gmail.
   File này là bí mật: git bỏ qua nó, đừng nộp hay gửi đi. Mẫu ở `deploy/.env.example`.
3. Mở **Git Bash** tại thư mục project, chạy (thay IP của bạn, nhập mật khẩu root khi được hỏi):
   ```bash
   bash deploy/deploy.sh root@103.20.30.40
   ```
   Script sẽ: build API → cài Docker trên VPS (lần đầu) → tải code lên → bật API + HTTPS → báo link.
4. Link API: `https://103-20-30-40.sslip.io`, Swagger: `https://103-20-30-40.sslip.io/swagger`.
5. Sửa code xong muốn cập nhật: chạy lại đúng lệnh ở bước 3.

Có tên miền riêng thì trỏ bản ghi A về IP VPS, rồi chạy `DOMAIN=api.ten-mien.com bash deploy/deploy.sh root@<IP>`.

Xem log khi có lỗi:
```bash
ssh root@103.20.30.40 "cd /opt/bakhi-api && docker compose logs --tail 100"
```

**Sau lần deploy đầu tiên, bắt buộc:** đăng nhập `admin / Admin@123` trên Swagger → `POST /api/users/me/change-password` đặt mật khẩu mạnh,
và `PUT /api/users/{id}` đổi email admin thành email thật (để nhận OTP).

**Khi thầy chấm:** OTP được gửi về email của tài khoản, nên thầy không nhận được mã của tài khoản demo.
Trong thời gian chấm có thể đặt `Otp__ReturnCodeInResponse=true` trong `deploy/.env` rồi deploy lại,
và cho app Flutter tự điền ô OTP khi response có `devCode`. Chấm xong thì đặt lại `false`.

---

## 2. Phân quyền

| role | Ai | Màn hình Flutter |
|------|----|------------------|
| `admin` | Quản trị | Trang quản trị: user, lớp |
| `teacher` | Giảng viên (nhân viên) | Dashboard GV: lớp mình dạy, buổi học, QR, điểm danh |
| `student` | Sinh viên | Trang SV: lớp mình học, quét QR, lịch sử |

Sau khi đăng nhập, dựa vào `user.role` trong response để chuyển trang.

---

## 3. Luồng đăng nhập (Flutter)

```
[Đăng ký]  POST /api/auth/register  ──┐
[Đăng nhập] POST /api/auth/login    ──┴─→ { ticket, purpose, channel, destination, expiresAt, devCode }
                                              ↓  (màn hình nhập OTP 6 số)
                                    POST /api/auth/verify-otp { ticket, code }
                                              ↓
                                    { token, expiresAt, user: { id, role, fullName, ... } }
```

- `login` nhận `username` là **tên đăng nhập hoặc email**, `otpChannel` là `"email"` (mặc định) hoặc `"sms"`.
- Nếu tài khoản chưa xác minh email, `login` trả `purpose: "verify-email"`; màn hình OTP xử lý giống hệt.
- Gửi lại mã: `POST /api/auth/resend-otp { ticket }` (cách nhau ≥ 30 giây). OTP hết hạn sau 5 phút, sai 5 lần phải đăng nhập lại.
- **Google (OAuth 2.0)**: Flutter dùng package `google_sign_in` lấy `idToken` → `POST /api/auth/google { idToken }` → nhận thẳng `{ token, user }`.
- **Quên mật khẩu**: `POST /api/auth/forgot-password { username, otpChannel? }` → màn hình nhập OTP + mật khẩu mới → `POST /api/auth/reset-password { ticket, code, newPassword }` → nhận `{ token, user }` (đăng nhập luôn).
- **Khuôn mặt**: `POST /api/auth/face-login { username, embedding }` → nhận `{ token, user }`. Xem mục "Khuôn mặt" bên dưới.
- Mỗi mã OTP chỉ dùng được cho đúng việc của nó (mã đăng nhập không dùng để đặt lại mật khẩu và ngược lại).

Mọi API còn lại cần header: `Authorization: Bearer <token>`.

```dart
const baseUrl = 'https://42-96-2-9.sslip.io';

Future<Map<String, dynamic>> api(String method, String path, {Object? body, String? token}) async {
  final req = http.Request(method, Uri.parse('$baseUrl$path'))
    ..headers['Content-Type'] = 'application/json';
  if (token != null) req.headers['Authorization'] = 'Bearer $token';
  if (body != null) req.body = jsonEncode(body);
  final res = await http.Response.fromStream(await req.send());
  final data = res.body.isEmpty ? null : jsonDecode(res.body);
  if (res.statusCode >= 400) throw Exception(data?['message'] ?? 'Lỗi ${res.statusCode}');
  return data is Map<String, dynamic> ? data : {'items': data};
}

// Đăng nhập
final challenge = await api('POST', '/api/auth/login', body: {'username': u, 'password': p, 'otpChannel': 'email'});
final auth = await api('POST', '/api/auth/verify-otp', body: {'ticket': challenge['ticket'], 'code': otp});
final token = auth['token'];
switch (auth['user']['role']) { case 'admin': ...; case 'teacher': ...; default: ... }
```

---

## 4. Danh sách API

### Auth (không cần token)
| Method | Đường dẫn | Body |
|--------|-----------|------|
| POST | `/api/auth/register` | `username, email, password, fullName, phone?, studentCode?` |
| POST | `/api/auth/login` | `username, password, otpChannel?` |
| POST | `/api/auth/verify-otp` | `ticket, code` |
| POST | `/api/auth/resend-otp` | `ticket` |
| POST | `/api/auth/google` | `idToken` |
| POST | `/api/auth/forgot-password` | `username, otpChannel?` |
| POST | `/api/auth/reset-password` | `ticket, code, newPassword` |
| POST | `/api/auth/face-login` | `username, embedding` |

### Người dùng
| Method | Đường dẫn | Quyền | Ghi chú |
|--------|-----------|-------|---------|
| GET | `/api/users/me` | mọi người | thông tin của mình |
| PUT | `/api/users/me` | mọi người | `fullName, phone?` |
| POST | `/api/users/me/change-password` | mọi người | `currentPassword, newPassword` |
| POST | `/api/users/me/face` | mọi người | đăng ký khuôn mặt: `embeddings: [[..],[..],[..]], password` |
| POST | `/api/users/me/face/verify` | mọi người | thử so khớp: `embedding` → `{ match, similarity, threshold }` |
| DELETE | `/api/users/me/face` | mọi người | xóa khuôn mặt của mình |
| DELETE | `/api/users/{id}/face` | admin | xóa khuôn mặt của user để đăng ký lại |
| GET | `/api/users?role=student&search=abc` | admin, GV | lọc theo role / từ khóa |
| GET | `/api/users/{id}` | admin, GV | |
| POST | `/api/users` | admin | `username, email, password, fullName, role, phone?, studentCode?` |
| PUT | `/api/users/{id}` | admin | `email, fullName, role, phone?, studentCode?, newPassword?` |
| DELETE | `/api/users/{id}` | admin | |

### Lớp học
| Method | Đường dẫn | Quyền | Ghi chú |
|--------|-----------|-------|---------|
| GET | `/api/classes` | mọi người | admin: tất cả, GV: lớp mình dạy, SV: lớp mình học |
| GET | `/api/classes/{id}` | có quyền với lớp | |
| POST | `/api/classes` | admin | `code, name, subject?, room?, teacherId?` |
| PUT | `/api/classes/{id}` | admin | như trên |
| DELETE | `/api/classes/{id}` | admin | xóa luôn buổi học + điểm danh |
| GET | `/api/classes/{id}/students` | admin, GV của lớp | |
| POST | `/api/classes/{id}/students` | admin, GV của lớp | `studentIds: [..]` |
| DELETE | `/api/classes/{id}/students/{studentId}` | admin, GV của lớp | |

### Buổi học
| Method | Đường dẫn | Quyền | Ghi chú |
|--------|-----------|-------|---------|
| GET | `/api/classes/{classId}/sessions` | có quyền với lớp | SV không thấy `qrToken` |
| POST | `/api/classes/{classId}/sessions` | admin, GV của lớp | `title, startTime, endTime, latitude?, longitude?, radiusMeters?, requireFace?` |
| GET / PUT / DELETE | `/api/sessions/{id}` | đọc: có quyền; sửa/xóa: admin, GV | |
| POST | `/api/sessions/{id}/qr` | admin, GV của lớp | `validMinutes?` (mặc định 5) → `{ qrToken, expiresAt }` |
| GET | `/api/sessions/{id}/attendance` | admin, GV của lớp | toàn bộ SV + trạng thái + tọa độ (dùng vẽ bản đồ) |

- Nếu buổi học có `latitude/longitude`, sinh viên phải ở trong `radiusMeters` (mặc định 100 m) mới điểm danh được.
- Nếu `requireFace: true`, sinh viên phải gửi kèm khuôn mặt khớp với chủ tài khoản (chống điểm danh hộ).

**Bản đồ điểm danh (chia sẻ vị trí):** mỗi dòng của `/api/sessions/{id}/attendance` có `latitude, longitude, distanceMeters, faceVerified`.
Flutter vẽ vòng tròn tâm = vị trí buổi học (`GET /api/sessions/{id}`), bán kính = `radiusMeters`, và 1 marker cho mỗi sinh viên đã điểm danh.
Gợi ý package `flutter_map` (bản đồ OpenStreetMap, miễn phí, không cần API key).

### Điểm danh
| Method | Đường dẫn | Quyền | Ghi chú |
|--------|-----------|-------|---------|
| POST | `/api/attendance/checkin` | SV | `qrToken, latitude?, longitude?, faceEmbedding?`. Trễ quá 15 phút sau giờ bắt đầu thì `late` |
| GET | `/api/attendance/me?classId=` | SV | lịch sử của mình |
| POST | `/api/attendance` | admin, GV | điểm danh thủ công: `sessionId, studentId, status, note?` |
| PUT | `/api/attendance/{id}` | admin, GV | `status, note?` |
| DELETE | `/api/attendance/{id}` | admin, GV | |
| GET | `/api/classes/{classId}/attendance/stats` | có quyền với lớp | thống kê + `warning` khi vắng ≥ 20% (SV chỉ thấy dòng của mình) |

`status`: `present` (có mặt), `late` (trễ), `absent` (vắng), `excused` (có phép), `pending` (buổi học chưa kết thúc, chưa điểm danh; chỉ xuất hiện trong roster).
`method`: `qr`, `manual` (GV điểm danh tay), `absence-request` (có phép nhờ đơn được duyệt).

### Khuôn mặt (đăng nhập + điểm danh)

Nhận diện chạy **trên điện thoại**, server chỉ lưu và so khớp vector. App gửi lên một mảng số (vector khuôn mặt), không gửi ảnh.

Cách làm phía Flutter:
1. `google_mlkit_face_detection`: tìm khuôn mặt trong ảnh camera. Bật `enableClassification` để đọc xác suất mở mắt, yêu cầu người dùng **nháy mắt** trước khi chụp (chống dùng ảnh in).
2. Cắt khuôn mặt, resize **112×112**, chuẩn hóa pixel `(x - 127.5) / 128`.
3. `tflite_flutter` + model **MobileFaceNet** (`mobilefacenet.tflite`) → ra **192 số**. Đó là `embedding`.
4. Đăng ký: chụp 3 góc (thẳng, hơi trái, hơi phải) → `POST /api/users/me/face { embeddings: [e1, e2, e3], password }`.
5. Đăng nhập: `POST /api/auth/face-login { username, embedding }`. Điểm danh: thêm `faceEmbedding` vào `/api/attendance/checkin`.

Quy tắc server:
- So khớp bằng cosine similarity, ngưỡng `Face:MatchThreshold` = **0.5** (tương đương khoảng cách 1.0 trong các hướng dẫn MobileFaceNet).
  Dùng `POST /api/users/me/face/verify` để xem điểm `similarity` thật và chỉnh ngưỡng nếu cần.
- Các mẫu lúc đăng ký phải giống nhau (cùng 1 người), và mọi vector phải cùng số chiều.
- Sai khuôn mặt **5 lần liên tiếp** (đăng nhập hoặc điểm danh) thì bị khóa **5 phút** (trả 429).
- `user.hasFace` cho biết tài khoản đã đăng ký khuôn mặt chưa.

### Đơn xin phép vắng kèm minh chứng (tính năng mới, mục 6)

Luồng: **SV chụp giấy tờ, gửi đơn → GV nhận email báo → GV xem ảnh, duyệt/từ chối → điểm danh buổi đó tự chuyển `excused` → SV nhận email kết quả.**

| Method | Đường dẫn | Quyền | Ghi chú |
|--------|-----------|-------|---------|
| POST | `/api/absence-requests` | SV | **multipart/form-data**: `sessionId, reason, category?, files[]` |
| POST | `/api/absence-requests/{id}/evidence` | SV (chủ đơn) | bổ sung file khi đơn còn `pending` |
| GET | `/api/absence-requests?status=&classId=` | mọi người | SV: đơn của mình, GV: đơn các lớp mình dạy, admin: tất cả |
| GET | `/api/absence-requests/{id}` | chủ đơn, GV của lớp, admin | |
| GET | `/api/absence-requests/{id}/evidence/{fileId}` | như trên | trả về ảnh/PDF; URL có sẵn trong `evidence[].url` |
| POST | `/api/absence-requests/{id}/review` | GV của lớp, admin | `{ status: "approved" \| "rejected", note? }` |
| DELETE | `/api/absence-requests/{id}` | SV (đơn `pending`), admin | hủy đơn, xóa luôn minh chứng |

Quy tắc:
- `category`: `sick` (ốm), `family` (việc gia đình), `event` (hoạt động trường), `other` (khác, mặc định).
- Đơn `status`: `pending` → `approved` / `rejected`. Bị từ chối thì được gửi lại đơn mới.
- Xin phép được **trước** buổi học, hoặc **sau** buổi học tối đa 7 ngày. Mỗi buổi chỉ 1 đơn đang chờ hoặc đã duyệt.
- Đã có mặt (`present`/`late`) thì không xin phép được. Đã được duyệt nghỉ mà vẫn đến lớp quét QR thì chuyển thành `present`.
- File: ảnh **JPG/PNG/WEBP hoặc PDF**, tối đa **5 file**, mỗi file **≤ 800 KB**. Server kiểm tra nội dung thật của file, đổi đuôi không qua được.
  File được lưu thẳng trong Firestore nên **không cần Firebase Storage** (gói miễn phí dùng được).

```dart
// Chọn ảnh đã nén sẵn để dưới 800 KB
final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);

final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/absence-requests'))
  ..headers['Authorization'] = 'Bearer $token'
  ..fields['sessionId'] = sessionId
  ..fields['reason'] = 'Bị sốt, có giấy khám bệnh'
  ..fields['category'] = 'sick'
  ..files.add(await http.MultipartFile.fromPath('files', img!.path));
final res = await http.Response.fromStream(await req.send());

// Hiển thị ảnh minh chứng (cần gửi token)
Image.network('$baseUrl${evidence['url']}', headers: {'Authorization': 'Bearer $token'});
```

---

## 5. Gợi ý chia việc Flutter

| Người | Màn hình |
|-------|----------|
| 1 | Đăng ký, đăng nhập, OTP, Google, quên mật khẩu, **đăng ký + đăng nhập bằng khuôn mặt**, điều hướng theo role |
| 2 | Admin: CRUD người dùng, CRUD lớp, thêm SV vào lớp, xóa khuôn mặt |
| 3 | Giảng viên: buổi học, hiện QR (`qr_flutter`), danh sách điểm danh, **bản đồ điểm danh** (`flutter_map`), thống kê, **duyệt đơn xin phép** |
| 4 | Sinh viên: quét QR (`mobile_scanner`) + GPS (`geolocator`) + khuôn mặt, lịch sử, cảnh báo vắng, **gửi đơn xin phép** (`image_picker`) |

Phần nhận diện khuôn mặt (ML Kit + MobileFaceNet) nên làm thành 1 widget dùng chung, vì cả người 1 và người 4 đều cần.
