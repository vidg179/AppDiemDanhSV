// Web không chạy được ML Kit/TFLite nên dùng bản báo "không hỗ trợ".
export 'face_embedder_stub.dart'
    if (dart.library.io) 'face_embedder_mobile.dart';
