Đặt file model nhận diện khuôn mặt vào thư mục này, đúng tên:

    mobilefacenet.tflite

Cách lấy: tìm trên GitHub các repo mẫu "flutter face recognition mobilefacenet",
tải file mobilefacenet.tflite (khoảng 5 MB) về và chép vào đây.
Model nhận ảnh 112x112 và trả về vector 192 số; app tự đọc kích thước từ model.

Sau khi chép file: chạy lại "flutter run" (không dùng hot reload).
Thiếu file này thì app vẫn chạy, chỉ báo lỗi khi dùng tính năng khuôn mặt.
