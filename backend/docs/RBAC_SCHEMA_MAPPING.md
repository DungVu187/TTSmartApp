# Mapping Schema User Và RBAC

Cập nhật ngày 24/07/2026.

## 1. Nguồn xác minh

- Nguồn tham chiếu chỉ đọc: database `dangnhap.net`.
- Kết quả discovery: `docs/web-auth-schema-discovery.txt`.
- Database phát triển là `TTSmartMobile_Dev`; script so sánh phải xác minh đúng tên database trước khi kết luận schema khớp.
- Backend không tạo migration, không dùng `EnsureCreated` và không thay đổi schema của hai database trên.

## 2. Bảng User

| Cột SQL | Kiểu SQL | Null | Mapping C# |
|---|---|---:|---|
| UserId | int identity | Không | `WebUser.UserId` |
| FullName | nvarchar(200) | Có | `string?` |
| UserName | nvarchar(100) | Không | `string` |
| Password | varchar(50) | Không | `string` |
| Email | varchar(50) | Có | `string?` |
| Code | nvarchar(100) | Có | `string?` |
| Avata | nvarchar(max) | Có | `string?` |
| UnitId | int | Có | `int?` |
| PositionId | int | Có | `int?` |
| DepartmentId | int | Có | `int?` |
| CompanyId | int | Có | `int?` |
| Address | nvarchar(200) | Có | `string?` |
| Phone | varchar(50) | Có | `string?` |
| KeyLock | nvarchar(40) | Có | `string?` nội bộ, không trả API |
| CreatedAt, UpdatedAt, TokenSince | datetime | Có | `DateTime?` |
| RegEmail | nvarchar(100) | Có | `string?` |
| RoleMax | int | Có | `int?` |
| RoleLevel | tinyint | Có | `byte?` |
| IsRoleGroup | bit | Có | `bool?` |
| UserCreateId, UserEditId | int | Có | `int?` |
| Status | tinyint | Có | `byte?` |
| BranchId | nvarchar(1000) | Có | `string?` |

Khóa chính vật lý: `PK_User(UserId)`. Không có unique index vật lý cho `UserName`.

## 3. Bảng Role

| Cột SQL | Kiểu SQL | Null | Mapping C# |
|---|---|---:|---|
| RoleId | int identity | Không | `WebRole.RoleId` |
| Code | nvarchar(100) | Không | `string` |
| Name | nvarchar(1000) | Không | `string` |
| Note | nvarchar(max) | Có | `string?` |
| CreatedAt, UpdatedAt | datetime | Có | `DateTime?` |
| UserEditId, UserId | int | Có | `int?` |
| LevelRole | tinyint | Có | `byte?` |
| Status | tinyint | Có | `byte?` |

Khóa chính vật lý: `PK_Role(RoleId)`. Không có unique index vật lý cho `Code` hoặc `Name`.

## 4. Bảng UserRole

| Cột SQL | Kiểu SQL | Null | Mapping C# |
|---|---|---:|---|
| UserRoleId | int identity | Không | `WebUserRole.UserRoleId` |
| UserId | int | Không | `WebUserRole.UserId` |
| RoleId | int | Không | `WebUserRole.RoleId` |
| CreatedAt | datetime | Có | `DateTime?` |
| Status | tinyint | Có | `byte?` |

- Khóa chính vật lý: `PK_UserRole(UserRoleId)`.
- Foreign key vật lý: `FK_UserRole_User(UserId -> User.UserId)`.
- `RoleId -> Role.RoleId` là quan hệ logic; discovery không thấy foreign key vật lý.
- Không có unique index vật lý cho cặp `(UserId, RoleId)`; service bảo đảm tối đa một assignment hiệu lực và khôi phục dòng xóa mềm khi có thể.

## 5. Bảng Function

| Cột SQL | Kiểu SQL | Null | Mapping C# |
|---|---|---:|---|
| FunctionId | int identity | Không | `WebFunction.FunctionId` |
| Name | nvarchar(200) | Không | `string` |
| Code | nvarchar(100) | Không | `string` |
| FunctionParentId | int | Không | `int` |
| Url | nvarchar(400) | Có | `string?` |
| Note | nvarchar(4000) | Có | `string?` |
| Location | int | Có | `int?` |
| Icon | nvarchar(1000) | Có | `string?` |
| CreatedAt, UpdatedAt | datetime | Có | `DateTime?` |
| UserId | int | Có | `int?` |
| Status | tinyint | Có | `byte?` |

- Khóa chính vật lý: `PK_Function(FunctionId)`.
- Root dùng `FunctionParentId = 0`; API đổi giá trị này thành `parentFunctionId: null`.
- Quan hệ cha-con là quan hệ logic; discovery không thấy foreign key vật lý cho `FunctionParentId`.

## 6. Bảng FunctionRole

| Cột SQL | Kiểu SQL | Null | Mapping C# |
|---|---|---:|---|
| FunctionRoleId | int identity | Không | `WebFunctionRole.FunctionRoleId` |
| TargetId | int | Không | `WebFunctionRole.TargetId` |
| FunctionId | int | Không | `WebFunctionRole.FunctionId` |
| ActiveKey | nvarchar(40) | Có | `string?` |
| Type | tinyint | Có | `byte?` |
| CreatedAt, UpdatedAt | datetime | Có | `DateTime?` |
| UserId | int | Có | `int?` |
| Status | tinyint | Có | `byte?` |

- Khóa chính vật lý: `PK_FunctionRole(FunctionRoleId)`.
- Foreign key vật lý: `FK_FunctionRole_Function(FunctionId -> Function.FunctionId)`.
- Với RBAC: `Type = 2` và `TargetId = RoleId`.
- `TargetId -> Role.RoleId` là quan hệ logic, không có foreign key vật lý.
- Cột vật lý dài tối đa 20 ký tự nhưng backend chỉ chấp nhận đúng 9 ký tự nhị phân.
- Không có unique index vật lý cho `(TargetId, FunctionId, Type)`; service hợp nhất dòng trùng hiệu lực khi cập nhật.

## 7. Trạng thái và quyền

- `Status = 1`: hiệu lực.
- `Status = 99`: ngừng hiệu lực hoặc xóa mềm.
- `ActiveKey[0..8]`: Xem, Tạo mới, Cập nhật, Xóa, Nhập, Xuất, In, Khác, D.Sách.
- `111111111`: đầy đủ; không có bit thứ 10.
- Nhiều Role được hợp nhất bằng OR từng bit theo từng Function.

## 8. Database object và chất lượng dữ liệu

Discovery của `dangnhap.net` không trả về trigger, check constraint, default constraint hoặc computed column cho năm bảng này. Chỉ có hai foreign key vật lý đã nêu ở trên.

Kết quả profile không chứa dữ liệu cá nhân:

- Có nhóm `UserName` trùng và không có unique index vật lý; login từ chối nếu có nhiều hơn một User hiệu lực cùng username.
- ActiveKey hiệu lực quan sát được gồm `000000000`, `111111101` và `111111111`.
- Password chủ yếu có dạng chuỗi hex 32 ký tự và được tạo theo công thức website `MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))`; encoding lấy từ `AuthDatabase:PasswordWriteMode`.
- `KeyLock`, `RegEmail` và `UserId` phải được giữ ổn định hoặc password hash phải được tạo lại khi một trong các giá trị này thay đổi.

## 9. Điểm chưa được xác minh

Schema và profile dữ liệu của `TTSmartMobile_Dev` đã được xác minh từ PowerShell người dùng bằng Windows Authentication:

- `compare-auth-schema.ps1` báo `The five-table auth/RBAC schemas match.`
- Database identity xác nhận đúng `dangnhap.net` và `TTSmartMobile_Dev`.
- `profile-auth-data.sql` trả toàn bộ issue bằng `0`.

Môi trường agent riêng vẫn không có credential Windows Authentication để tự mở kết nối SQL Server. Vì vậy phần còn lại cần xác minh là E2E qua HTTP API trên SQL Server thật, không phải mapping schema.
