# Backend Issues

Cập nhật ngày 24/07/2026.

## 1. Schema và profile dữ liệu clone đã xác minh

Người dùng đã chạy thành công kiểm tra read-only trên `.\SQLEXPRESS` bằng Windows Authentication:

~~~text
The five-table auth/RBAC schemas match.
Source: D:\TTSmartApp\backend\docs\dangnhap-auth-schema.txt
Development: D:\TTSmartApp\backend\docs\ttsmartmobile-dev-auth-schema.txt
~~~

Đã xác minh database identity thực tế:

- Nguồn: `dangnhap.net`.
- Phát triển: `TTSmartMobile_Dev`.
- Cả hai database đều `ONLINE`, cùng compatibility level `120` và cùng collation `SQL_Latin1_General_CP1_CI_AS`.
- 73 dòng schema discovery của năm bảng khớp nhau.

Script đối chiếu vẫn là read-only và không được chạy theo chế độ ghi trên database production.

## 2. Quan hệ logic không có đủ foreign key vật lý

Discovery chỉ thấy:

- `FunctionRole.FunctionId -> Function.FunctionId`.
- `UserRole.UserId -> User.UserId`.

Không thấy foreign key vật lý cho `UserRole.RoleId`, `FunctionRole.TargetId` hoặc `Function.FunctionParentId`. Backend kiểm tra các liên kết trước khi ghi và không tạo migration/FK mới.

## 3. Không có unique index cho các assignment legacy

Discovery không thấy unique index cho username, cặp UserRole hoặc bộ TargetId/FunctionId/Type. Service chủ động:

- Từ chối login khi có nhiều User hiệu lực cùng username.
- Không tạo assignment hiệu lực trùng.
- Khôi phục dòng xóa mềm trước khi tạo dòng mới nếu có thể.

Profile trên `TTSmartMobile_Dev` đã chạy thành công:

| Bảng | Tổng | Hiệu lực | Không hiệu lực |
|---|---:|---:|---:|
| `User` | 231 | 144 | 87 |
| `Role` | 9 | 9 | 0 |
| `UserRole` | 576 | 149 | 427 |
| `Function` | 17 | 14 | 3 |
| `FunctionRole` | 121 | 121 | 0 |

Các kiểm tra orphan, parent không hợp lệ, `Type`, `ActiveKey` và assignment hiệu lực trùng đều có kết quả `0`.

## 4. Password dùng MD5 legacy

Phần lớn password có dạng hex 32 ký tự. Backend đã áp dụng đúng công thức website `MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))`; hash lớp đầu dùng hex chữ thường như `ts-md5`, encoding lấy từ `AuthDatabase:PasswordWriteMode` và mặc định là `Md5Utf8`.

`KeyLock` và `RegEmail` là dữ liệu đầu vào của password hash. Endpoint cập nhật user không cho đổi `RegEmail` cho đến khi có luồng đổi email kèm reset mật khẩu.

MD5 không an toàn cho hệ thống mới. Chưa nâng cấp hash vì app và web dự kiến dùng chung cơ chế đăng nhập/database. Chỉ nâng cấp sau khi xác nhận tương thích ngược với website.

## 5. Ý nghĩa nghiệp vụ của bit D.Sách

Vị trí bit thứ 9 đã được xác nhận từ giao diện web và backend đã parse/expose đúng. Endpoint nghiệp vụ cụ thể dùng bit này chưa được người dùng xác nhận; các module sau phải khai báo rõ trước khi áp dụng.

## 6. DateTime legacy không có timezone

Cột `datetime` không chứa offset. API hiện chuẩn hóa giá trị theo timezone local của server rồi trả UTC ở các field có hậu tố `Utc`. Cần xác nhận timezone production trước module nghiệp vụ phụ thuộc thời gian.

## 7. NuGet vulnerability audit trong môi trường offline

Restore/build/test dùng package cache local thành công nhưng có cảnh báo `NU1900` do không truy cập được vulnerability service của nuget.org. Cần chạy lại restore/audit trong môi trường có mạng trước production.

## 8. SQL Server E2E đã xác minh trên database clone

Đã chạy HTTP integration test bằng WebApplicationFactory/InMemory và runner SQL Server thật bằng Windows Authentication. Runner `scripts/run-auth-e2e.ps1` báo `PASS` trên `TTSmartMobile_Dev` ngày 24/07/2026.

Đã xác minh qua API thật:

- Login, `/api/auth/me` và đổi mật khẩu MD5 legacy.
- CRUD User/Role/Function, UserRole và FunctionRole.
- 9 bit ActiveKey, phân biệt Xem/D.Sách và thay đổi quyền trực tiếp trong database.
- 401/403, chống tự nâng quyền và khóa User sau khi JWT đã cấp.
- SQL translation/collation thực tế, transaction path và cleanup dữ liệu test.

Bootstrap User/Role/Function/FunctionRole dùng prefix `E2E_20260724143149_9542` đã được cleanup mềm; không chuyển connection sang database production.

