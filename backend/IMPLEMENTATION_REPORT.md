# Implementation Report

Cập nhật ngày 30/07/2026.

## Trạng thái hiện tại

Backend đã mở rộng từ nền tảng User/RBAC sang các luồng quản lý công ty và trạm để mobile tích hợp theo từng vertical slice:

- Authentication: đăng nhập, `/me`, đăng xuất, đổi mật khẩu và thu hồi JWT theo `TokenSince`.
- User/RBAC: CRUD, phân trang, lọc, gán Role, ma trận Function/FunctionRole và kiểm tra ActiveKey 9 bit.
- Phạm vi dữ liệu: `ADMIN` toàn hệ thống, `CONGTY` theo `CompanyId`, `QUANLY` theo danh sách `User.BranchId`.
- Company: CRUD, lọc `Status`, khóa dịch vụ, ngày hết hạn theo giờ Việt Nam, logo và quota tài khoản.
- Branch: CRUD, khôi phục, lọc công ty/loại trạm, kiểm tra mã không phân biệt hoa thường và che mật khẩu trong response.
- User assignment: tài khoản cấp công ty tạo User role thấp hơn `CONGTY` phải gán ít nhất một Branch cùng Company; assignment legacy hợp lệ được giữ nguyên khi chỉ sửa hồ sơ.
- Password policy cho dữ liệu tạo mới: tối thiểu 8 ký tự, gồm chữ thường, chữ hoa, số và một trong `@#$%`; login legacy vẫn dùng công thức hash tương thích website.

Đã xác minh bằng `dotnet test`, `dotnet build`, `dotnet format --verify-no-changes` và SQL E2E trên `TTSmartMobile_Dev`; lần kiểm tra gần nhất đạt `68/68` test, build không warning/error và E2E PASS.

Phần Dashboard dữ liệu vận hành chưa triển khai connection động theo `Branch.Dataname`. Cần xác nhận mapping giữa `QUANLYTAITRAM_Local` và một `Branch` test trước khi đọc các bảng `TRAMTRON`, `LSTRON` và `GIAMSATTRON`. Không ghi vào `dangnhap.net`.

## 1. Phạm vi đã triển khai

Đã hoàn thiện nền tảng User + RBAC cho backend ASP.NET Core để Flutter dùng trực tiếp, dựa trên năm bảng legacy:

- `User`.
- `Role`.
- `UserRole`.
- `Function`.
- `FunctionRole`.

Database phát triển được cấu hình qua `ConnectionStrings:AuthConnection`, mặc định local là `TTSmartMobile_Dev`. Database `dangnhap.net` chỉ dùng tham chiếu read-only.

## 2. Mapping và quy ước

- ID dùng `int identity` theo schema web.
- `Status = 1` là hiệu lực; `Status = 99` là ngừng hiệu lực/xóa mềm.
- `FunctionRole.Type = 2`; `FunctionRole.TargetId = RoleId`.
- `FunctionParentId` là `int NOT NULL`; root lưu `0`, API trả `null`.
- ActiveKey đúng 9 ký tự: Xem, Tạo mới, Cập nhật, Xóa, Nhập, Xuất, In, Khác, D.Sách.
- `111111111` là đầy đủ; nhiều Role được hợp nhất bằng OR từng bit.
- Mapping chi tiết: `docs/RBAC_SCHEMA_MAPPING.md`.

Mapping đã được đối chiếu trực tiếp giữa `dangnhap.net` và `TTSmartMobile_Dev`; 73 dòng schema discovery của năm bảng khớp nhau. Hai database đều `ONLINE`, cùng compatibility level `120` và cùng collation `SQL_Latin1_General_CP1_CI_AS`.

Profile `TTSmartMobile_Dev` đã xác minh 231 User, 9 Role, 576 UserRole, 17 Function và 121 FunctionRole. Các kiểm tra orphan, parent không hợp lệ, `Type`, `ActiveKey` và assignment hiệu lực trùng đều có kết quả `0`.

## 3. API đã triển khai

### Authentication

- `POST /api/auth/login`.
- `GET /api/auth/me`.
- `POST /api/auth/change-password`.
- Mật khẩu dùng đúng công thức website `MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))`; encoding cấu hình bằng `AuthDatabase:PasswordWriteMode`, mặc định `Md5Utf8`.
- JWT dùng signing key từ configuration/user-secrets/environment; không chứa ActiveKey làm nguồn quyền.
- User bị khóa hoặc quyền database thay đổi có hiệu lực ở request kế tiếp.

### User

- Phân trang, tìm kiếm, lọc Status và lọc Role.
- Xem/tạo/sửa User.
- Khóa/mở khóa và xóa mềm.
- Reset mật khẩu quản trị.
- Thay toàn bộ UserRole trong transaction; assignment xóa mềm được khôi phục thay vì tạo trùng.
- Không cho tự khóa, tự xóa hoặc tự thay Role của tài khoản hiện tại theo các luồng nguy hiểm.

### Role

- Phân trang, tìm kiếm, lọc Status, xem số User và số Function được gán.
- Tạo/sửa/khóa/mở khóa/xóa mềm Role.
- `GET /api/roles/{id}/function-matrix` trả toàn bộ Function hiệu lực, kể cả Function chưa gán.
- `PUT /api/roles/{id}/functions` cập nhật toàn bộ ma trận trong transaction.
- `PUT /api/roles/{id}/functions/{functionId}/active-key` cập nhật một ActiveKey.
- `DELETE /api/roles/{id}/functions/{functionId}` xóa mềm FunctionRole.
- Bảo vệ Role quản trị cuối cùng có quyền cập nhật QLQ.

### Function

- Danh sách phẳng, tìm kiếm và lọc Status.
- `GET /api/functions/tree` trả cây `children` cho menu mobile.
- Tạo/sửa/xóa mềm Function; kiểm tra parent tồn tại và chống vòng lặp.
- Không cho đổi mã, ngừng hiệu lực hoặc xóa ba Function quản trị `QLND`, `QLQ`, `QLCN`.

## 4. Authorization

Authorization dùng policy/handler chung và đọc database ở từng request:

| Nhóm | Function code | GET | POST | PUT/PATCH | DELETE |
|---|---|---:|---:|---:|---:|
| User | `QLND` | Xem/chi tiết | Tạo mới | Cập nhật | Xóa |
| Role/quyền | `QLQ` | Xem/chi tiết | Tạo mới | Cập nhật | Xóa |
| Function/menu | `QLCN` | Xem/chi tiết | Tạo mới | Cập nhật | Xóa |

Danh sách dùng bit D.Sách (8), chi tiết dùng bit Xem (0). Các bit Nhập, Xuất, In và Khác đã có helper/DTO/authorization primitive để module nghiệp vụ sau khai báo đúng bit.

## 5. Bảo mật và DTO

- Không trả `Password`, `KeyLock` hoặc hash.
- Không bind Entity trực tiếp; request/response dùng DTO.
- Validation ActiveKey bắt buộc đúng `^[01]{9}$`.
- Trả `401` cho token không hợp lệ/user bị khóa và `403` cho thiếu quyền.
- JWT claim được chuẩn hóa thành `sub`, `unique_name`, `role`.
- Không hardcode JWT signing key hoặc connection string production.

## 6. Test và build

Đã chạy từ package cache local:

- `dotnet restore .\TTSmart.sln --ignore-failed-sources -p:RestorePackagesPath=C:\Users\TTSmart\.nuget\packages`: thành công; còn cảnh báo NU1900 do không truy cập được vulnerability service.
- `dotnet format .\TTSmart.sln --verify-no-changes --no-restore`: thành công.
- `dotnet test .\TTSmart.sln -c Release --no-restore`: **36/36 pass**.
- `dotnet build .\TTSmart.sln -c Release --no-restore`: thành công, **1 cảnh báo NU1900, 0 error**.

Test bao phủ công thức mật khẩu website hai lớp, ActiveKey đủ 9 bit, mapping metadata SQL Server, SQL translation query Role, login đúng/sai/khóa, đổi mật khẩu, /me, hợp nhất nhiều Role, UserRole, User CRUD, Role CRUD, Function CRUD/tree, matrix, xóa mềm FunctionRole, admin cuối cùng, HTTP 401/403, quyền đổi tức thời sau JWT, khóa user sau JWT, OpenAPI và không lộ field nhạy cảm.

## 7. Database đã thay đổi

- `dangnhap.net`: không có thao tác ghi, migration, restore hoặc seed.
- Ngày 24/07/2026, E2E trên `TTSmartMobile_Dev` đã PASS bằng tài khoản quản trị hiện có, xác minh đăng nhập với công thức mật khẩu website hai lớp, `/api/auth/me`, CRUD User/Role/Function, UserRole, FunctionRole, đổi mật khẩu, ActiveKey động, khóa user và `401/403`.
- Runner đã cleanup dữ liệu theo prefix `E2E_20260724153937_5046` trong `finally`; không giữ dữ liệu E2E hiệu lực.
- Không có thay đổi schema hoặc database object nào được tạo.

## 8. File chính đã thêm/sửa

- `src/TTSmart.Api/Program.cs` và cấu hình JWT/SQL Server.
- `src/TTSmart.Api/Data/WebAuth/*`.
- `src/TTSmart.Api/Features/Auth/*`.
- `src/TTSmart.Api/Features/Authorization/*`.
- `src/TTSmart.Api/Features/AccessManagement/*`.
- `src/TTSmart.Api/Controllers/AuthController.cs`.
- `src/TTSmart.Api/Controllers/UsersController.cs`.
- `src/TTSmart.Api/Controllers/RolesController.cs`.
- `src/TTSmart.Api/Controllers/FunctionsController.cs`.
- `tests/TTSmart.Api.Tests/*`, gồm HTTP integration test bằng WebApplicationFactory và test metadata mapping SQL Server.
- `scripts/profile-auth-data.sql`, `scripts/compare-auth-schema.ps1` và `scripts/run-auth-e2e.ps1`.
- `docs/RBAC_API_CONTRACT.md`.
- `docs/RBAC_PERMISSION_MATRIX.md`.
- `docs/RBAC_SCHEMA_MAPPING.md`.
- `BACKEND_ISSUES.md`.

## 9. Kết quả SQL Server E2E và production gate

Runner `scripts/run-auth-e2e.ps1` đã chạy thành công trên `TTSmartMobile_Dev` ngày 24/07/2026:

~~~text
[E2E] PASS - User/RBAC SQL Server clone smoke test hoàn tất.
~~~

Đã xác minh qua API thật: login, `/api/auth/me`, danh sách/cây Function, CRUD User/Role/Function, UserRole, FunctionRole, đổi mật khẩu, phân biệt Xem/D.Sách, 401/403, chống tự nâng quyền, sửa ActiveKey trực tiếp trong DB, khóa User sau JWT, validation ma trận và cleanup dữ liệu test.

Chưa đổi `ConnectionStrings:AuthConnection` sang `dangnhap.net` hoặc database production. Chỉ thực hiện khi người dùng chấp thuận riêng và có kế hoạch backup/rollback.

