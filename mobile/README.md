# TTsmart Mobile

Ứng dụng Flutter mobile nội bộ TTsmart, kết nối ASP.NET Core Web API bằng
HTTPS/JSON. Mobile không kết nối trực tiếp SQL Server.

## Chạy local

Flutter SDK mặc định của workspace:

```powershell
C:\Users\TTSmart\dev\flutter\bin\flutter.bat pub get
C:\Users\TTSmart\dev\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5052
```

`API_BASE_URL` mặc định là `http://10.0.2.2:5052` cho Android Emulator. Khi
dùng thiết bị thật hoặc môi trường khác, truyền địa chỉ API qua
`--dart-define`; không đưa URL production hoặc secret vào source.

## Kiểm tra nhẹ

```powershell
C:\Users\TTSmart\dev\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test
C:\Users\TTSmart\dev\flutter\bin\flutter.bat analyze
C:\Users\TTSmart\dev\flutter\bin\flutter.bat test test/features/auth test/features/access_management
```

Không cần bật app, emulator, ADB hoặc build APK cho kiểm tra contract/model.

## Phân hệ hiện có

- Đăng nhập JWT, khôi phục phiên bằng `GET /api/auth/me`, secure storage và
  đổi mật khẩu.
- App Shell với menu sinh từ function backend; không hardcode theo tên role.
- Tài khoản: danh sách, tìm kiếm, lọc trạng thái, phân trang, chi tiết, tạo,
  sửa, gán role, khóa/mở khóa, reset mật khẩu và xóa.
- Vai trò: danh sách, tìm kiếm, lọc trạng thái, phân trang, tạo, sửa, chi tiết, xóa và
  cấu hình ma trận function bằng `ActiveKey` 9 quyền.
- Function/menu: danh sách cây, tìm kiếm, tạo, sửa, chi tiết và xóa.

## Contract backend

Repository Flutter dùng đầy đủ route `/api/auth`, `/api/users`, `/api/roles` và
`/api/functions` theo tài liệu backend. ID resource là số nguyên; query danh sách
dùng `status=1` hoặc `status=99`; payload trạng thái dùng `isActive`; payload role
dùng `roleIds`; payload ma trận dùng `functions[].functionId` và `activeKey`.

Function code quyền mobile:

- `QLND`: danh sách/chi tiết/thao tác người dùng.
- `QLQ`: danh sách/chi tiết vai trò và ma trận quyền.
- `QLCN`: cây function/menu.

`ActiveKey` có đúng 9 vị trí: Xem, Tạo mới, Cập nhật, Xóa, Nhập, Xuất, In, Khác,
D.Sách. `full` được tính từ chín quyền này.

Response phân trang, `camelCase`, ProblemDetails, `401`, `403`, `404`, `409` và
validation field errors được xử lý ở `lib/core/network/` và data layer từng feature.

Backend là source of truth cho validation và authorization. Mobile chỉ kiểm tra
đầu vào để hỗ trợ trải nghiệm; không chứa connection string SQL Server, token,
mật khẩu hoặc tài khoản development.
