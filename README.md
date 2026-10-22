# Điểm danh HUTECH: ứng dụng điểm danh sinh viên

Ứng dụng di động (Flutter) kèm API (ASP.NET Core + Firebase Firestore) để giảng viên điểm danh sinh viên bằng **QR + GPS + khuôn mặt**, sinh viên **xin phép vắng kèm minh chứng**. Bài kiểm tra môn Lập trình thiết bị di động.

- **API đang chạy (có HTTPS):** https://42-96-2-9.sslip.io
- **Tài liệu API, thử trực tiếp (Swagger):** https://42-96-2-9.sslip.io/swagger
- **Tài khoản demo cho thầy:** nhóm gửi riêng (không đưa lên GitHub vì lý do bảo mật).

## Thành phần

| Thư mục | Nội dung |
|---|---|
| [`app/`](app) | Ứng dụng Flutter (Android), gọi API qua HTTPS |
| [`api/`](api) | Backend ASP.NET Core 10, lưu dữ liệu trên Firebase Firestore, kèm script deploy lên VPS (Docker + Caddy tự lo HTTPS) |

```
Flutter app  ──HTTPS──▶  ASP.NET Core API  ──▶  Firebase Firestore
 (điện thoại)            (VPS, JWT + OTP)         (cơ sở dữ liệu)
```

## Đối chiếu yêu cầu của đề

| Yêu cầu | Trạng thái | Cách làm |
|---|---|---|
| 1. Đăng ký qua email | Có | Đăng ký + xác minh email bằng OTP |
| 1. Đăng ký bên thứ 3 (OAuth 2.0) | Server có, app chưa có nút | Endpoint `POST /api/auth/google` (xác thực Google idToken). Đề ghi "hoặc" nên dùng đăng ký email |
| 2. Đăng nhập + OTP | Có (email) | Tên đăng nhập + mật khẩu + OTP gửi qua email thật (Gmail SMTP). OTP qua SMS chạy được luồng nhưng chưa gửi thật (cần Twilio có phí) |
| 3. Phân quyền | Có | `admin` vào trang quản trị, `teacher` (giảng viên) vào dashboard giảng viên, `student` vào trang sinh viên |
| 4. CRUD | Có | Người dùng, lớp học, sinh viên trong lớp, buổi học, điểm danh, đơn xin phép |
| 5a. Khuôn mặt | Có | Đăng ký 3 góc, đăng nhập bằng khuôn mặt, điểm danh có xác thực khuôn mặt (ML Kit + MobileFaceNet chạy trên điện thoại) |
| 5b. QR Code | Có | Giảng viên chiếu mã QR (hiệu lực 60 giây), sinh viên quét để điểm danh |
| 5c. Chia sẻ vị trí | Có | Sinh viên gửi GPS khi điểm danh, ngoài bán kính cho phép thì bị chặn. Giảng viên xem bản đồ vị trí từng sinh viên |
| 6. Tính năng thêm | Có | **Xin phép vắng kèm minh chứng**: sinh viên chụp giấy khám bệnh gửi đơn, giảng viên duyệt thì trạng thái tự chuyển thành "có phép" |
| 7. Giao diện | Có | Material 3, màu theo logo HUTECH, chế độ sáng/tối, chạy tốt cỡ điện thoại |

Chức năng thêm: thống kê chuyên cần và cảnh báo sinh viên vắng từ 20% buổi, quên mật khẩu bằng OTP, điểm danh tay khi sinh viên gặp lỗi.

## Luồng sử dụng chính

1. **Admin** tạo giảng viên, tạo lớp, gán giảng viên, thêm sinh viên vào lớp.
2. **Giảng viên** tạo buổi học (đặt vị trí phòng, bán kính, có thể bật yêu cầu khuôn mặt), bấm **Chiếu mã QR** (60 giây).
3. **Sinh viên** quét QR, app tự lấy GPS (và chụp mặt nếu buổi học yêu cầu) rồi điểm danh.
4. Hết 60 giây QR tắt, giảng viên thấy danh sách: tạo mã mới cho người chưa kịp quét, hoặc điểm danh tay cho người bị lỗi.
5. Sinh viên vắng có lý do thì **xin phép kèm ảnh**, giảng viên duyệt, điểm danh tự chuyển thành "có phép".

## Công nghệ

- **App:** Flutter 3.47 / Dart 3.13, `http`, `mobile_scanner` (quét QR), `qr_flutter`, `geolocator`, `flutter_map` (OpenStreetMap), `image_picker`, `google_mlkit_face_detection`, `tflite_flutter` (model MobileFaceNet).
- **API:** ASP.NET Core 10, Firebase Firestore, JWT, BCrypt, Swagger.
- **Triển khai:** Docker + Caddy (HTTPS tự động) trên VPS Ubuntu.

## Chạy ứng dụng

Yêu cầu: Flutter SDK, Android Studio (hoặc điện thoại Android bật USB debugging). App mặc định gọi API đang chạy ở địa chỉ nêu trên, **không cần chạy API** vẫn dùng được.

```bash
cd app
flutter pub get
flutter run            # chạy trên điện thoại/máy ảo Android
flutter test           # chạy bộ test tự động
flutter build apk      # tạo file APK
```

Lưu ý:
- Nhận diện khuôn mặt, quét QR bằng camera và GPS thật chỉ chạy trên **điện thoại Android** (hoặc máy ảo có camera). Bản web dùng để xem giao diện.
- Địa chỉ API đặt ở [`app/lib/core/config.dart`](app/lib/core/config.dart).
- Model nhận diện khuôn mặt `mobilefacenet.tflite` (MIT) đã có sẵn trong [`app/assets/models`](app/assets/models).
- `app/lib/main_demo.dart` là bản chạy với dữ liệu giả để xem giao diện: `flutter run -d chrome -t lib/main_demo.dart` rồi mở `?role=admin`, `?role=teacher` hoặc `?role=student`.

## Chạy API (tùy chọn, để tự dựng server)

Yêu cầu: .NET 10 SDK, một project Firebase đã bật Firestore.

1. Tải khóa service account của Firebase, đặt tên `firebase-key.json`, chép vào thư mục `api/` (file này **không** nằm trong repo).
2. Điền `Firebase:ProjectId` trong `api/appsettings.json`.
3. Copy `api/appsettings.Development.example.json` thành `api/appsettings.Development.json`, đặt khóa JWT và mật khẩu admin.
4. Chạy:
   ```bash
   cd api
   dotnet run
   ```
   Mở `/swagger` để thử API. Chi tiết endpoint, cách cấu hình OTP qua email và cách deploy lên VPS xem [`api/README.md`](api/README.md).

## Bảo mật

Không có khóa Firebase, mật khẩu, khóa JWT hay tài khoản demo nào trong repo. Các giá trị này nằm trong `firebase-key.json` và `deploy/.env` (đã được `.gitignore`).

## Thông tin nhóm

- Môn học: Lập trình thiết bị di động, Trường Đại học Công nghệ TP.HCM (HUTECH)
- Thành viên: *(điền họ tên, MSSV các thành viên)*
