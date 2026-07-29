# TTSmart Backend

Backend ASP.NET Core Web API cho Flutter nội bộ, dùng EF Core và SQL Server.

## Database

- dangnhap.net: database clone từ web, chỉ đọc để khảo sát schema và dữ liệu.
- TTSmartMobile_Dev: database phát triển/kiểm thử; Development đã cấu hình trỏ tới database này.
- Production app và web sẽ dùng chung database web khi schema/connection đã được xác minh.
- Backend giữ khóa cấu hình ConnectionStrings:AuthConnection; đổi môi trường bằng configuration hoặc biến môi trường ConnectionStrings__AuthConnection.
- Không chạy migration, EnsureCreated, seed hoặc script ghi lên dangnhap.net.

Năm bảng auth/RBAC được map đúng tên web:

~~~text
User, Role, UserRole, Function, FunctionRole
~~~

Không còn dùng schema thử nghiệm cũ User_Role, Role_Function, ActiveRight hoặc Right.

## ActiveKey 9 quyền

FunctionRole.ActiveKey là 9 ký tự theo thứ tự:

~~~text
Xem | Tạo mới | Cập nhật | Xóa | Nhập | Xuất | In | Khác | D.Sách
  0 |    1    |     2    |  3  |  4   |  5   | 6  |  7   |   8
~~~

111111111 là đầy đủ. Checkbox Đầy đủ trên web/mobile là trạng thái tổng hợp, không phải bit thứ 10.

Khi user có nhiều role, backend OR từng bit quyền và vẫn trả roleFunctions theo từng assignment.

## API

- POST /api/auth/login
- GET /api/auth/me
- POST /api/auth/change-password
- CRUD /api/users, khóa/mở khóa, reset mật khẩu, thay thế UserRole
- CRUD /api/roles, trạng thái, ma trận FunctionRole đầy đủ và xóa mềm một assignment
- CRUD /api/functions, danh sách phẳng, endpoint cây cha-con và trạng thái

Endpoint bổ sung cho Flutter:

- GET /api/roles/{id}/function-matrix
- DELETE /api/roles/{id}/functions/{functionId}
- GET /api/functions/tree

Contract mobile: docs/RBAC_API_CONTRACT.md

Ma trận quyền: docs/RBAC_PERMISSION_MATRIX.md

Mapping schema: docs/RBAC_SCHEMA_MAPPING.md

## Cấu hình local

JWT signing key không đặt trong source. Dùng user-secrets hoặc biến môi trường:

~~~powershell
dotnet user-secrets set "Jwt:SigningKey" "<chuoi-it-nhat-32-ky-tu>" --project .\src\TTSmart.Api\TTSmart.Api.csproj
~~~

Mật khẩu database web dùng công thức legacy hai lớp để tương thích website:

~~~text
MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))
~~~

Mobile gửi mật khẩu gốc qua HTTPS; backend tự thực hiện cả hai lớp băm. Hash lớp đầu dùng hex chữ thường như `ts-md5`. Encoding của hai lớp được cấu hình bằng:

~~~text
AuthDatabase:PasswordWriteMode = Md5Utf8 hoặc Md5Unicode
~~~

MD5 không dùng cho thiết kế mật khẩu mới độc lập ngoài yêu cầu tương thích legacy.

Vì `RegEmail` tham gia công thức hash, API cập nhật user không cho thay đổi giá trị này. Khi nghiệp vụ cần đổi `RegEmail`, phải thiết kế luồng đổi kèm reset mật khẩu để tạo lại hash tương thích web.

## Chạy

~~~powershell
dotnet run --project .\src\TTSmart.Api\TTSmart.Api.csproj --launch-profile http
~~~

OpenAPI Development: http://localhost:5052/openapi/v1.json

## Kiểm tra

So sánh read-only schema auth giữa database chuẩn và database phát triển bằng Windows Authentication:

~~~powershell
.\scripts\compare-auth-schema.ps1
~~~

Script tạo docs/dangnhap-auth-schema.txt và docs/ttsmartmobile-dev-auth-schema.txt, sau đó trả lỗi nếu mapping 5 bảng khác nhau.

Sau khi schema khớp, profile dữ liệu chỉ đọc trên database phát triển:

~~~powershell
sqlcmd -S .\SQLEXPRESS -E -d master -b -W -s "|" -v DatabaseName="TTSmartMobile_Dev" -i .\scripts\profile-auth-data.sql
~~~

Profile kiểm tra trạng thái, dữ liệu mồ côi, assignment trùng, Type và ActiveKey bất thường; không trả password hoặc dữ liệu cá nhân.

Smoke/E2E User + RBAC trên SQL Server clone:

~~~powershell
.\scripts\run-auth-e2e.ps1 -BootstrapAdmin -StartApi
~~~

Với `-BootstrapAdmin`, script tạo một tài khoản quản trị E2E tạm bằng mật khẩu sinh trong bộ nhớ, gán các Role hiệu lực và không phụ thuộc mật khẩu legacy. Script chỉ cho phép database `TTSmartMobile_Dev`, kiểm tra login, đổi mật khẩu, `/me`, CRUD User/Role/Function, UserRole, FunctionRole, 401/403, chống tự nâng quyền, thay đổi `ActiveKey` trực tiếp và khóa User sau JWT. Dữ liệu test có prefix `E2E_` và được cleanup trong `finally`. Nếu API đang chạy thì bỏ `-StartApi`.

~~~powershell
dotnet restore .\TTSmart.sln
dotnet build .\TTSmart.sln -c Release
dotnet test .\TTSmart.sln -c Release
dotnet format .\TTSmart.sln --verify-no-changes --no-restore
~~~

Test hiện gồm unit test và HTTP integration test bằng WebApplicationFactory cho login, JWT, 401/403, quyền thay đổi tức thời, khóa user, OpenAPI, dữ liệu nhạy cảm, cây Function và ma trận Role. Test InMemory không thay thế kiểm tra SQL translation/E2E trên TTSmartMobile_Dev.

## Quy tắc bảo mật

- Không commit connection string thật, JWT secret, mật khẩu hoặc password hash.
- Không trả Password, KeyLock hoặc hash trong DTO.
- Backend luôn kiểm tra authentication/authorization; mobile chỉ ẩn menu/nút để hỗ trợ UX.
- Status = 1 là hiệu lực, Status = 99 là ngừng hiệu lực/xóa mềm.
