# Báo Cáo Kiểm Tra Frontend

Ngày cập nhật: `2026-07-24`

## Phạm vi đã cập nhật

- Đồng bộ model Auth, User, Role, Function và `roleFunctions` với backend hiện tại.
- Loại bỏ contract cũ `right`, `possibleRight`, `disabled`, ID chuỗi và mã function cũ.
- Tập trung xử lý `ActiveKey` 9 quyền trong `permission_models.dart`.
- Cập nhật repository cho auth, user, role, function, function tree và function-matrix.
- Thiết kế lại App Shell, danh sách/chi tiết/form User, Role, Function và ma trận quyền theo hướng mobile-first.

## Kiểm tra nhẹ

- `dart format lib test`: thành công, format 53 file và thay đổi định dạng 20 file.
- `dart analyze`: thành công, kết quả `No issues found!`.
- `flutter analyze`: đã thử nhưng vượt quá 120 giây nên dừng; không có kết quả hoàn tất từ lệnh này.
- Đã cập nhật fixture unit/repository test cho contract mới, gồm parse nullable, role object,
  `roleFunctions`, ActiveKey, `isActive`, `roleIds`, `status=1/99` và endpoint
  `/api/roles/{id}/function-matrix`.
- Lệnh test gộp vượt quá 180 giây; test model đơn lẻ với `--no-pub --concurrency=1`
  vẫn vượt quá 120 giây. Các tiến trình Dart do hai lệnh test tạo đã được dừng để tránh
  tiếp tục chiếm tài nguyên.
- Không bật app, emulator, thiết bị thật, ADB, backend/database hoặc APK theo yêu cầu phần cứng.

## Chưa thể xác minh runtime

- Chưa xác minh login thật, điều hướng runtime, layout trên kích thước thiết bị thật,
  phản hồi backend thật hoặc hành vi 401/403/409 end-to-end.
- Các nhánh lỗi được xử lý theo `ApiException`/ProblemDetails và cần chạy test/runtime
  trong môi trường có Flutter SDK cùng backend Development để xác nhận cuối cùng.

## Giả định và contract gap

- Response backend được giả định đúng các DTO trong `AccessManagementContracts.cs` và
  `AuthContracts.cs`, gồm các field nullable và response envelope phân trang.
- Function tree được lấy từ `/api/functions/tree`; việc lọc theo search/status vẫn do backend
  quyết định.
- Sau khi lưu ma trận role thành công, mobile gọi lại `/api/auth/me`; nếu request refresh
  thất bại sau khi backend đã lưu, UI báo lỗi để người dùng thử lại thay vì giả định phiên đã mới.
