# Điểm danh HUTECH

Ứng dụng di động giúp **giảng viên điểm danh sinh viên** bằng mã QR, vị trí GPS và khuôn mặt; sinh viên có thể **xin phép vắng kèm ảnh minh chứng** ngay trong app. Bài kiểm tra môn *Lập trình thiết bị di động*, Trường Đại học Công nghệ TP.HCM (HUTECH).

| | |
|---|---|
| **API đang chạy (HTTPS)** | https://42-96-2-9.sslip.io |
| **Tài liệu API, thử trực tiếp** | https://42-96-2-9.sslip.io/swagger |
| **Tài khoản demo** | Nhóm gửi riêng cho thầy (không để trong repo vì lý do bảo mật) |

---

## Mục lục

1. [Ứng dụng làm được gì](#1-ứng-dụng-làm-được-gì)
2. [Đối chiếu với yêu cầu của đề](#2-đối-chiếu-với-yêu-cầu-của-đề)
3. [Luồng sử dụng điển hình](#3-luồng-sử-dụng-điển-hình)
4. [Kiến trúc và công nghệ](#4-kiến-trúc-và-công-nghệ)
5. [Cấu trúc thư mục](#5-cấu-trúc-thư-mục)
6. [Chạy ứng dụng](#6-chạy-ứng-dụng)
7. [Chạy API (tùy chọn)](#7-chạy-api-tùy-chọn)
8. [Quy tắc nghiệp vụ quan trọng](#8-quy-tắc-nghiệp-vụ-quan-trọng)
9. [Kiểm thử](#9-kiểm-thử)
10. [Bảo mật](#10-bảo-mật)
11. [Hạn chế đã biết](#11-hạn-chế-đã-biết)
12. [Thông tin nhóm](#12-thông-tin-nhóm)

---

## 1. Ứng dụng làm được gì

App có **3 vai trò**. Sau khi đăng nhập, mỗi người vào đúng trang của mình.

### Quản trị viên (admin)
- Quản lý **người dùng**: thêm, sửa, xóa, tìm kiếm, lọc theo vai trò, đặt lại khuôn mặt đã đăng ký.
- Quản lý **lớp học**: thêm, sửa, xóa, gán giảng viên phụ trách.
- Quản lý **sinh viên trong lớp**: thêm nhiều sinh viên một lúc, xóa khỏi lớp.

### Giảng viên
- Xem **lớp mình dạy**, tạo / sửa / xóa **buổi học** (giờ học, vị trí phòng, bán kính cho phép, bật "yêu cầu khuôn mặt").
- **Chiếu mã QR** điểm danh, hiệu lực **60 giây**. Hết giờ thì QR tắt, hiện danh sách để:
  - tạo **mã mới** cho người chưa kịp quét,
  - **điểm danh tay** cho sinh viên bị lỗi (Có mặt / Trễ / Có phép / Vắng, kèm ghi chú).
- Xem **bản đồ** vị trí từng sinh viên lúc điểm danh.
- Xem **thống kê chuyên cần**, sinh viên vắng từ 20% số buổi trở lên bị tô đỏ cảnh báo.
- **Duyệt đơn xin phép**: xem ảnh/PDF minh chứng, duyệt hoặc từ chối kèm ghi chú.

### Sinh viên
- **Quét QR** để điểm danh. App tự gửi kèm GPS, và chụp khuôn mặt nếu buổi học yêu cầu.
- Xem **lịch sử điểm danh** từng buổi và **chuyên cần** của mình.
- **Xin phép vắng**: chọn lý do, viết giải trình, chụp tối đa 5 ảnh minh chứng. Theo dõi trạng thái đơn, hủy đơn đang chờ duyệt.
- **Đăng ký khuôn mặt** (3 góc), **đăng nhập bằng khuôn mặt**.

### Chung cho mọi vai trò
Đăng ký bằng email, đăng nhập bằng mật khẩu + OTP, quên mật khẩu, sửa hồ sơ, đổi mật khẩu, giao diện sáng/tối.

---

## 2. Đối chiếu với yêu cầu của đề

| Yêu cầu | Trạng thái | Cách thực hiện |
|---|---|---|
| **1.** Đăng ký qua email | Có | Đăng ký rồi xác minh email bằng OTP |
| **1.** Đăng ký bên thứ ba (OAuth 2.0) | Server có, app chưa có nút | Endpoint `POST /api/auth/google` xác thực Google idToken. Đề ghi "hoặc" nên dùng đăng ký email |
| **2.** Đăng nhập: tên đăng nhập + mật khẩu + OTP | Có (OTP email) | OTP 6 số gửi qua Gmail, hết hạn sau 5 phút. Server hỗ trợ cả OTP SMS nhưng chưa nối nhà cung cấp SMS (xem [Hạn chế](#11-hạn-chế-đã-biết)) |
| **3.** Phân quyền | Có | `admin` vào trang quản trị, `teacher` (giảng viên) vào dashboard giảng viên, `student` vào trang sinh viên. API chặn theo vai trò ở phía server |
| **4.** CRUD | Có | Người dùng, lớp học, sinh viên trong lớp, buổi học, điểm danh, đơn xin phép |
| **5a.** Đăng nhập / điểm danh bằng khuôn mặt | Có | ML Kit tìm khuôn mặt, MobileFaceNet tạo vector chạy ngay trên điện thoại, server so khớp bằng cosine similarity |
| **5b.** Quét QR | Có | Giảng viên chiếu QR, sinh viên quét để điểm danh |
| **5c.** Chia sẻ vị trí | Có | Sinh viên gửi GPS, ngoài bán kính thì bị chặn. Giảng viên xem bản đồ OpenStreetMap |
| **5d / 6.** Tính năng thêm | Có | **Xin phép vắng kèm minh chứng**: giảng viên duyệt thì điểm danh tự chuyển thành "có phép" |
| **7.** Giao diện đẹp, dễ dùng | Có | Material 3, màu theo logo HUTECH, chế độ sáng/tối |

Ba lớp chống điểm danh hộ: **QR** (đang ở lớp) + **GPS** (đúng vị trí) + **khuôn mặt** (đúng người).

---

## 3. Luồng sử dụng điển hình

```
Admin          tạo lớp ─▶ gán giảng viên ─▶ thêm sinh viên vào lớp
Giảng viên     tạo buổi học (vị trí, bán kính) ─▶ Chiếu mã QR (60 giây)
Sinh viên      quét QR ─▶ (GPS tự gửi) ─▶ (chụp mặt nếu cần) ─▶ điểm danh xong
Hết 60 giây    QR tắt ─▶ giảng viên tạo mã mới / điểm danh tay ─▶ xem bản đồ, thống kê
Xin phép       sinh viên gửi đơn + ảnh ─▶ giảng viên duyệt ─▶ buổi đó thành "Có phép"
```

---

## 4. Kiến trúc và công nghệ

```
 App Flutter (Android)  ──HTTPS + JWT──▶  API ASP.NET Core 10  ──▶  Firebase Firestore
   điện thoại                              chạy trên VPS Ubuntu       cơ sở dữ liệu
                                           (Docker + Caddy)
```

| Thành phần | Công nghệ |
|---|---|
| **App** | Flutter 3.47, Dart 3.13, Material 3 |
| Quét / chiếu QR | `mobile_scanner`, `qr_flutter` |
| Vị trí, bản đồ | `geolocator`, `flutter_map` (OpenStreetMap, không cần API key) |
| Ảnh minh chứng | `image_picker` |
| Khuôn mặt | `google_mlkit_face_detection` + `tflite_flutter` (model MobileFaceNet) |
| **API** | ASP.NET Core 10, Swagger, JWT, BCrypt |
| Cơ sở dữ liệu | Firebase Firestore |
| Gửi OTP | Gmail SMTP |
| **Triển khai** | Docker, Caddy (tự cấp HTTPS), script deploy một lệnh |

---

## 5. Cấu trúc thư mục

```
.
├── README.md             tài liệu này
├── app/                  ỨNG DỤNG FLUTTER
│   ├── lib/
│   │   ├── core/         gọi API, lưu đăng nhập, theme, hàm dùng chung
│   │   ├── face/         nhận diện khuôn mặt (ML Kit + TFLite)
│   │   ├── screens/
│   │   │   ├── auth/       đăng nhập, đăng ký, OTP, quên mật khẩu
│   │   │   ├── admin/      quản lý người dùng, lớp học
│   │   │   ├── teacher/    buổi học, QR, điểm danh, bản đồ, thống kê, duyệt đơn
│   │   │   ├── student/    quét QR, lịch sử, xin phép vắng
│   │   │   └── common/     hồ sơ, đăng ký khuôn mặt, sinh viên trong lớp
│   │   └── widgets/      thành phần giao diện dùng chung
│   ├── assets/           logo HUTECH, model nhận diện khuôn mặt
│   └── test/             bộ test tự động
└── api/                  API ASP.NET CORE
    ├── Controllers/      Auth, Users, Classes, Sessions, Attendance, AbsenceRequests
    ├── Services/         JWT, gửi OTP, nhận diện khuôn mặt
    ├── Models/ Dtos/ Data/ Infrastructure/
    ├── deploy/           Dockerfile, docker-compose, Caddy, script deploy lên VPS
    └── README.md         tài liệu chi tiết các endpoint
```

---

## 6. Chạy ứng dụng

**Yêu cầu:** Flutter SDK 3.47 trở lên, Android Studio (hoặc điện thoại Android bật USB debugging).
App **mặc định gọi API đang chạy** ở địa chỉ nêu đầu trang, nên **không cần dựng server** vẫn dùng được.

```bash
cd app
flutter pub get
flutter run            # chạy trên điện thoại hoặc máy ảo Android
flutter test           # chạy bộ test tự động
flutter build apk      # tạo file APK cài lên điện thoại
```

Lưu ý:
- **Khuôn mặt, quét QR bằng camera và GPS** chỉ hoạt động đúng trên **điện thoại Android** (hoặc máy ảo có camera). Bản web chỉ để xem giao diện.
- Địa chỉ API đặt ở [`app/lib/core/config.dart`](app/lib/core/config.dart).
- Model nhận diện khuôn mặt `mobilefacenet.tflite` (giấy phép MIT) đã có trong [`app/assets/models`](app/assets/models).
- Xem giao diện nhanh bằng dữ liệu giả, không cần đăng nhập:
  `flutter run -d chrome -t lib/main_demo.dart` rồi mở `?role=admin`, `?role=teacher` hoặc `?role=student`.

---

## 7. Chạy API (tùy chọn)

Chỉ cần khi muốn tự dựng server riêng. **Yêu cầu:** .NET 10 SDK và một project Firebase đã bật Firestore.

1. Tải khóa service account của Firebase, đặt tên `firebase-key.json`, chép vào thư mục `api/` (file này **không** nằm trong repo).
2. Điền `Firebase:ProjectId` trong `api/appsettings.json`.
3. Copy `api/appsettings.Development.example.json` thành `api/appsettings.Development.json`, đặt khóa JWT và mật khẩu admin.
4. Chạy:
   ```bash
   cd api
   dotnet run
   ```
5. Mở `/swagger` để thử API.

Cách cấu hình gửi OTP qua email, danh sách đầy đủ endpoint và hướng dẫn deploy lên VPS xem [`api/README.md`](api/README.md).

---

## 8. Quy tắc nghiệp vụ quan trọng

| Nội dung | Quy tắc |
|---|---|
| **Mã QR** | Hiệu lực 60 giây, mỗi mã gắn với một buổi học. Hết hạn thì giảng viên tạo mã mới |
| **GPS** | Nếu buổi học đặt vị trí, sinh viên phải ở trong bán kính cho phép (mặc định 100 m) |
| **Trễ** | Quét QR sau 15 phút kể từ giờ bắt đầu thì tính là "Trễ" |
| **Khuôn mặt** | So khớp cosine similarity, ngưỡng 0.5. Sai 5 lần liên tiếp bị khóa 5 phút |
| **OTP** | 6 số, hết hạn sau 5 phút, sai tối đa 5 lần, gửi lại sau 30 giây |
| **Xin phép** | Xin trước buổi học hoặc sau tối đa 7 ngày. Mỗi buổi một đơn. Tối đa 5 ảnh JPG/PNG/WEBP hoặc PDF, mỗi file ≤ 800 KB |
| **Cảnh báo vắng** | Vắng từ 20% số buổi đã học (không tính buổi có phép) |
| **Phiên đăng nhập** | Token JWT có hiệu lực 24 giờ |

---

## 9. Kiểm thử

- **App:** 24 test tự động (`flutter test`) kiểm tra từng màn hình với API giả: quản trị, giảng viên, sinh viên, khuôn mặt, đăng nhập, hồ sơ.
- **API:** đã chạy 108 ca kiểm thử đầu-cuối trên Firebase thật và trên server đã deploy: đăng ký, OTP, phân quyền, CRUD, QR + GPS, khuôn mặt, xin phép vắng, quên mật khẩu.

---

## 10. Bảo mật

- Mật khẩu băm bằng BCrypt; token JWT; OTP chỉ lưu dạng băm và chỉ dùng được cho đúng một việc (đăng nhập, xác minh email hoặc đặt lại mật khẩu).
- Giới hạn gửi OTP, khóa tạm khi nhập sai nhiều lần, kiểm tra nội dung thật của file tải lên (không tin phần đuôi file).
- Phân quyền kiểm tra ở **phía server**, không chỉ ẩn nút trong app.
- App chỉ gửi **dãy số đặc trưng** của khuôn mặt lên server, không gửi ảnh.
- **Không có khóa Firebase, mật khẩu, khóa JWT hay tài khoản demo nào trong repo.** Các giá trị này nằm ngoài repo (`firebase-key.json`, `deploy/.env`) và đã được `.gitignore`.

---

## 11. Hạn chế đã biết

- **OTP qua SMS:** server đã có luồng gửi SMS nhưng chưa nối nhà cung cấp (cần dịch vụ Twilio có phí), nên app hiện chỉ dùng OTP qua **email**.
- **Đăng nhập Google:** server đã có, app chưa có nút (cần tạo Client ID trên Google Cloud). Đề cho phép "hoặc", nên dùng đăng ký email.
- **Khuôn mặt:** nhận diện chạy trên điện thoại nên về lý thuyết dãy số đặc trưng có thể bị giả mạo. Với phạm vi bài môn học thì chấp nhận được.
- Chỉ build và thử cho **Android**.

---

## 12. Thông tin nhóm

- **Môn học:** Lập trình thiết bị di động
- **Trường:** Đại học Công nghệ TP.HCM (HUTECH)
- **Thành viên:** *(điền họ tên và MSSV)*
