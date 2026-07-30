# TTSmart Backend

Tài liệu bàn giao backend ASP.NET Core cho dự án TTSmartApp.

Cập nhật gần nhất: **30/07/2026**.

## 1. Mục tiêu và phạm vi hiện tại

Backend phục vụ ứng dụng Flutter nội bộ, dùng database và cấu trúc nghiệp vụ của website công ty làm nền tảng.

Phạm vi đang ưu tiên:

- Đăng nhập dùng chung tài khoản và công thức mật khẩu của website.
- Phân quyền theo User, Role, Function và ActiveKey 9 bit.
- Quản lý người dùng theo phạm vi công ty và trạm.
- Quản lý công ty.
- Quản lý trạm trộn và trạm cân.
- Chuẩn bị API ổn định để phía mobile tích hợp.

Phạm vi **chưa triển khai**:

- Dashboard sản lượng và dữ liệu vận hành tại trạm.
- Kết nối động tới database được ghi trong `Branch.Dataname`.
- Đồng bộ database giữa website, server và máy trạm.
- Các phân hệ báo cáo, xe, camera, cấp phối, vật liệu, cân ô tô và in phiếu.

`QUANLYTAITRAM_Local` là một database vận hành đặt tại trạm. Backend hiện **không sử dụng database này** và chưa cần dùng khi đang hoàn thiện các chức năng quản trị theo website.

## 2. Công nghệ

- C# và ASP.NET Core Web API.
- Target framework: `.NET 10`.
- Entity Framework Core SQL Server.
- Microsoft SQL Server/SQL Server Express.
- JWT Bearer Authentication.
- OpenAPI JSON tích hợp sẵn.
- xUnit và `WebApplicationFactory` cho test.

Phiên bản đã xác minh trên máy hiện tại:

~~~text
.NET SDK 10.0.302
SQL Server Express: .\SQLEXPRESS
API local: http://localhost:5052
~~~

## 3. Kiến trúc và cấu trúc thư mục

~~~text
backend/
├─ src/TTSmart.Api/
│  ├─ Controllers/                 HTTP endpoint, binding và response
│  ├─ Features/
│  │  ├─ Auth/                     Đăng nhập, /me, logout, đổi mật khẩu
│  │  ├─ Authorization/            Policy, Role hệ thống, ActiveKey
│  │  ├─ AccessManagement/         User, Role, Function, FunctionRole
│  │  ├─ CompanyManagement/        Quản lý công ty, khóa, hạn, logo
│  │  └─ BranchManagement/         Quản lý trạm
│  ├─ Data/
│  │  ├─ WebAuth/                  Mapping User/Role/Function
│  │  └─ Company/                  Mapping Company/Branch
│  ├─ Common/                      Exception, security, time, OpenAPI
│  ├─ Properties/launchSettings.json
│  ├─ appsettings.json
│  └─ appsettings.Development.json
├─ tests/TTSmart.Api.Tests/        Unit và HTTP integration test
├─ docs/                            Contract, mapping và tài liệu khảo sát
├─ scripts/                         SQL/PowerShell phục vụ kiểm tra backend
├─ skills/                          Skill cục bộ dành cho agent backend
├─ AGENTS.md                        Quy tắc làm việc riêng của backend
├─ IMPLEMENTATION_REPORT.md         Báo cáo triển khai chi tiết
└─ TTSmart.sln
~~~

Controller được giữ mỏng. Nghiệp vụ nằm trong `Features/<FeatureName>`. DTO API tách khỏi entity EF Core. `Program.cs` chỉ đóng vai trò composition root.

## 4. Database

### 4.1. `dangnhap.net`

- Bản clone local của database website đang chạy.
- Là nguồn tham chiếu schema và dữ liệu web.
- Chỉ được khảo sát read-only.
- Không được chạy insert, update, delete, migration, seed hoặc thay đổi schema.
- Không chứa các bảng sản lượng như `TRAMTRON`, `LSTRON` hoặc `GIAMSATTRON`.

### 4.2. `TTSmartMobile_Dev`

- Database phát triển và kiểm thử bắt buộc của backend.
- Được clone từ dữ liệu web để phát triển an toàn.
- Mọi API local và E2E đang ghi vào database này.
- Có thể chứa các bản ghi E2E đã xóa mềm `Status = 99`; số lượng dòng có thể lớn hơn bản clone ban đầu.

### 4.3. `QUANLYTAITRAM_Local`

- Database vận hành mẫu tại một trạm.
- Có các bảng như `TRAMTRON`, `LSTRON`, `GIAMSATTRON`.
- Chưa được kết nối vào backend hiện tại.
- Không được mặc định ghép với một `BranchId` nếu chưa xác nhận mapping.

### 4.4. Connection string

Hai DbContext hiện tại cùng dùng một khóa cấu hình:

~~~text
ConnectionStrings:AuthConnection
~~~

Development mặc định:

~~~text
Server=.\SQLEXPRESS;Database=TTSmartMobile_Dev;Trusted_Connection=True;TrustServerCertificate=True;
~~~

Có thể thay cấu hình mà không sửa code bằng biến môi trường:

~~~powershell
$env:ConnectionStrings__AuthConnection = "Server=.\SQLEXPRESS;Database=TTSmartMobile_Dev;Trusted_Connection=True;TrustServerCertificate=True;"
~~~

Không hardcode connection string production trong source.

### 4.5. Thay đổi schema riêng của database dev

Backend Company hiện cần cột:

~~~text
dbo.Company.IsLocked bit NOT NULL DEFAULT 0
~~~

Nếu clone lại `TTSmartMobile_Dev` từ nguồn chưa có cột này, chạy **chỉ trên database dev**:

~~~powershell
.\scripts\add-company-islocked.ps1
~~~

Script tự từ chối database khác `TTSmartMobile_Dev`. Không tự chạy script này trên `dangnhap.net` hoặc production.

## 5. Cấu hình nhạy cảm và tương đương file .env

.NET không bắt buộc dùng file `.env`. Dự án dùng thứ tự cấu hình chuẩn của ASP.NET Core:

1. `appsettings.json` cho cấu hình không nhạy cảm.
2. `appsettings.Development.json` cho cấu hình local không chứa secret.
3. User Secrets cho secret trên máy lập trình.
4. Biến môi trường hoặc secret manager khi production.

`Properties/launchSettings.json` chỉ chứa profile chạy local; không phải nơi lưu secret. File `.csproj` cũng không phải nơi lưu secret.

### JWT signing key local

~~~powershell
dotnet user-secrets set "Jwt:SigningKey" "<chuoi-ngau-nhien-it-nhat-32-ky-tu>" `
  --project .\src\TTSmart.Api\TTSmart.Api.csproj
~~~

Có thể dùng biến môi trường cho phiên PowerShell hiện tại:

~~~powershell
$env:Jwt__SigningKey = "<chuoi-ngau-nhien-it-nhat-32-ky-tu>"
~~~

User Secrets được lưu theo tài khoản Windows và **không đi theo Git hoặc khi chuyển máy**. Phải cấu hình lại trên máy mới.

Không đưa mật khẩu tài khoản, JWT key, connection string production hoặc password hash vào README, commit, ảnh chụp hay log.

## 6. Thiết lập trên máy mới

### 6.1. Phần mềm cần cài

- Git.
- .NET SDK 10.
- SQL Server hoặc SQL Server Express.
- SQL Server Management Studio nếu cần restore/kiểm tra database.
- `sqlcmd` để chạy script kiểm tra và E2E.
- PowerShell.

### 6.2. Những dữ liệu không tự đi theo source code

Khi đổi máy cần chuyển hoặc tạo lại riêng:

- Database `TTSmartMobile_Dev`.
- Database `dangnhap.net` nếu muốn tiếp tục đối chiếu local.
- JWT User Secret.
- Connection string riêng của máy mới nếu server instance khác.
- File logo trong `src/TTSmart.Api/uploads/company-logos/` nếu cần giữ logo đã upload ở local.

`src/TTSmart.Api/uploads/` đang bị Git ignore. Database cũng không được lưu trong repository. Thư mục `backups/` hiện chỉ có artifact lịch sử EmployeeManagement, không phải backup database TTSmart hiện tại.

### 6.3. Trình tự thiết lập đề xuất

~~~powershell
Set-Location D:\TTSmartApp\backend

dotnet restore .\TTSmart.sln

dotnet user-secrets set "Jwt:SigningKey" "<chuoi-ngau-nhien-it-nhat-32-ky-tu>" `
  --project .\src\TTSmart.Api\TTSmart.Api.csproj

dotnet build .\TTSmart.sln -c Release

dotnet test .\TTSmart.sln -c Release --no-restore
~~~

Sau khi restore database, kiểm tra `Company.IsLocked`. Chỉ chạy script bổ sung cột nếu database dev chưa có cột đó.

## 7. Chạy backend

Từ thư mục `D:TTSmartAppackend`:

~~~powershell
dotnet run `
  --project .\src\TTSmart.Api\TTSmart.Api.csproj `
  --launch-profile http
~~~

Khi chạy thành công sẽ có log:

~~~text
Now listening on: http://localhost:5052
Application started. Press Ctrl+C to shut down.
~~~

OpenAPI Development:

~~~text
http://localhost:5052/openapi/v1.json
~~~

Dự án hiện chỉ cung cấp OpenAPI JSON, chưa cài Swagger UI.

## 8. Quy ước API chung

- Base URL local: `http://localhost:5052`.
- JSON dùng `camelCase`.
- Authentication dùng header `Authorization: Bearer <accessToken>`.
- Lỗi trả theo ASP.NET Core `ProblemDetails` và có `traceId`.
- Timestamp có thời gian trả theo UTC và thường có hậu tố `Utc`.
- Ngày nghiệp vụ dùng `yyyy-MM-dd`.
- `Status = 1`: đang hiệu lực.
- `Status = 99`: xóa mềm/ngừng hiệu lực.
- Danh sách lớn dùng phân trang server-side.
- Backend luôn kiểm tra quyền và data scope; mobile ẩn menu/nút chỉ để hỗ trợ giao diện.

## 9. Authentication và session

### Endpoint

- `POST /api/auth/login`.
- `GET /api/auth/me`.
- `POST /api/auth/logout`.
- `POST /api/auth/change-password`.

### Công thức mật khẩu website

Backend tương thích công thức legacy:

~~~text
MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))
~~~

Mobile gửi mật khẩu gốc qua HTTPS. Backend tự thực hiện cả hai lớp hash. Chế độ encoding được cấu hình bằng:

~~~text
AuthDatabase:PasswordWriteMode = Md5Utf8 hoặc Md5Unicode
~~~

Mặc định hiện tại là `Md5Utf8`.

`RegEmail` tham gia công thức hash nên API cập nhật User không cho đổi trực tiếp trường này. Muốn đổi phải thiết kế luồng đổi kèm reset mật khẩu.

### Chính sách mật khẩu mới

Áp dụng khi tạo User, reset password, change password và tạo/sửa password Branch:

- Tối thiểu 8 ký tự.
- Có chữ thường.
- Có chữ hoa.
- Có số.
- Có ít nhất một ký tự `@`, `#`, `$` hoặc `%`.

Login tài khoản legacy không ép chính sách mới; chỉ kiểm tra hash hiện có.

### JWT và logout

- Access token mặc định có hạn 60 phút.
- Quyền không được coi là cố định trong JWT; backend đọc lại trạng thái User và quyền database ở từng request.
- Logout cập nhật `User.TokenSince` và vô hiệu mọi JWT cũ của cùng tài khoản.
- Đổi hoặc reset mật khẩu cũng thu hồi JWT cũ.
- Hiện chưa có Refresh Token.
- Vì chỉ có một `TokenSince`, logout đang tương đương đăng xuất toàn bộ thiết bị của cùng tài khoản.

Không có tài khoản admin hoặc mật khẩu demo được hardcode trong source. E2E có thể tạo bootstrap admin tạm.

## 10. RBAC và ActiveKey 9 bit

Năm bảng legacy đã map:

~~~text
User
Role
UserRole
Function
FunctionRole
~~~

`FunctionRole.Type = 2` và `FunctionRole.TargetId = RoleId`.

`ActiveKey` phải có đúng 9 ký tự:

| Vị trí | Quyền |
|---:|---|
| 0 | Xem |
| 1 | Tạo mới |
| 2 | Cập nhật |
| 3 | Xóa |
| 4 | Nhập |
| 5 | Xuất |
| 6 | In |
| 7 | Khác |
| 8 | D.Sách |

`111111111` là đầy đủ. Checkbox “Đầy đủ” chỉ là trạng thái UI tổng hợp, không phải bit thứ 10.

Nếu User có nhiều Role legacy, backend OR từng bit để tính quyền hiệu lực và vẫn trả `roleFunctions` theo từng assignment.

Các mã Function đã gắn authorization policy:

- `QLND`: Người dùng.
- `QLQ`: Phân quyền/Role.
- `QLCN`: Chức năng.
- `QLCT`: Công ty.
- `QLTT`: Trạm.

`ADMIN` được coi là Super Admin và bỏ qua ActiveKey, data scope công ty, trạng thái khóa và ngày hết hạn của công ty.

## 11. Data scope theo Role

### `ADMIN`

- Xem và thao tác toàn hệ thống.
- Có thể chọn công ty/trạm để xem phạm vi mong muốn.
- Không bị chặn bởi Company lock hoặc ngày hết hạn.
- Được phép vượt quota User khi tạo hoặc khôi phục tài khoản.

### `CONGTY`

- Chỉ truy cập `User.CompanyId` của chính tài khoản.
- Xem toàn bộ Branch đang hiệu lực thuộc công ty đó.
- Có thể quản lý tài khoản con trong công ty nếu có ActiveKey tương ứng.
- Khi tạo hoặc đổi Role cho tài khoản con phải gán đúng một Role thấp hơn `CONGTY`.

### Role thấp hơn `CONGTY`, ví dụ `QUANLY`

- Phạm vi trạm lấy từ chuỗi `User.BranchId`, ví dụ `10,12`.
- Backend parse, loại ID trùng và chuẩn hóa chuỗi.
- Branch phải `Status = 1` và thuộc đúng `User.CompanyId`.
- Không thể xem dữ liệu chéo công ty chỉ bằng cách truyền `companyId` hoặc `branchId` khác từ mobile.

Dữ liệu legacy có một assignment QUANLY chéo công ty đã được phát hiện. Backend không tự sửa dữ liệu này; chỉ cho giữ nguyên khi cập nhật hồ sơ không thay Company/Role/Branch. Khi thay assignment, dữ liệu phải hợp lệ theo quy tắc mới.

## 12. API User, Role và Function

### User

- `GET /api/users`.
- `GET /api/users/{id}`.
- `POST /api/users`.
- `PUT /api/users/{id}`.
- `PUT /api/users/{id}/status`.
- `PUT /api/users/{id}/roles`.
- `POST /api/users/{id}/reset-password`.
- `DELETE /api/users/{id}`.

Nghiệp vụ đã có:

- Phân trang, tìm kiếm, lọc Status và Role.
- Tạo, sửa, xóa mềm, reset mật khẩu và thay Role trong transaction.
- Từ chối username đang được User active sử dụng.
- User mới luôn phải có ít nhất một Role.
- Tài khoản không phải ADMIN chỉ được gán đúng một Role thấp hơn `CONGTY`.
- Tài khoản thấp hơn `CONGTY` phải có ít nhất một Branch cùng Company.
- Chủ doanh nghiệp không được xóa ADMIN hoặc tài khoản `CONGTY` ngang cấp.
- Không cho tự khóa, tự xóa hoặc tự thay Role trong các luồng nguy hiểm.
- `Status = 99` giải phóng quota tài khoản con.

`PUT /api/users/{id}/status` vẫn tồn tại trong backend và hỗ trợ khóa/mở khóa User. Nghiệp vụ đã từng chốt rằng mobile có thể không hiển thị chức năng khóa tài khoản con; cần quyết định sau có giữ endpoint này hay chỉ giới hạn cho ADMIN.

### Quota tài khoản công ty

- `Company.CountUser` là số tài khoản con active tối đa.
- Không tính User có Role `ADMIN` hoặc `CONGTY`.
- Tài khoản công ty bị chặn tạo/khôi phục nếu đã đủ quota.
- ADMIN được tạo/khôi phục vượt quota.
- Giảm quota xuống thấp hơn số đang dùng không tự xóa hoặc khóa tài khoản cũ; chỉ chặn tạo/khôi phục thêm.

### Role và ma trận quyền

- `GET /api/roles`.
- `GET /api/roles/{id}`.
- `POST /api/roles`.
- `PUT /api/roles/{id}`.
- `PUT /api/roles/{id}/status`.
- `GET /api/roles/{id}/function-matrix`.
- `PUT /api/roles/{id}/functions`.
- `PUT /api/roles/{id}/functions/{functionId}/active-key`.
- `DELETE /api/roles/{id}/functions/{functionId}`.
- `DELETE /api/roles/{id}`.

Ma trận trả cả Function chưa gán với `activeKey = 000000000`. Cập nhật toàn ma trận chạy trong transaction và khôi phục assignment đã xóa mềm khi có thể.

### Function

- `GET /api/functions`.
- `GET /api/functions/tree`.
- `GET /api/functions/{id}`.
- `POST /api/functions`.
- `PUT /api/functions/{id}`.
- `PUT /api/functions/{id}/status`.
- `DELETE /api/functions/{id}`.

Đã có cây cha-con, kiểm tra parent, chống vòng lặp và bảo vệ ba Function quản trị `QLND`, `QLQ`, `QLCN` khỏi thay đổi nguy hiểm.

## 13. Quản lý Công ty

### Endpoint

- `GET /api/companies`.
- `GET /api/companies/{id}`.
- `POST /api/companies`.
- `PUT /api/companies/{id}`.
- `PUT /api/companies/{id}/lock`.
- `PUT /api/companies/{id}/expiration`.
- `POST /api/companies/{id}/logo`.
- `GET /api/companies/{id}/logo`.
- `DELETE /api/companies/{id}`.
- `POST /api/companies/{id}/restore`.

### Nghiệp vụ đã triển khai

- Danh sách mặc định `Status = 1`.
- Phân trang, tìm kiếm, lọc `Status` và `IsLocked`.
- Tạo Company chỉ dành cho ADMIN.
- Bắt buộc `Code`, `Name`, `Email` và `Phone`.
- `CountUser >= 0`.
- `Active` chỉ nhận `0` hoặc `1` theo dữ liệu web: 0 miễn phí, 1 trả phí.
- Mã Company được trim, phân biệt hoa/thường và chỉ cần duy nhất giữa các dòng `Status = 1`.
- Xóa mềm bằng `Status = 99`; có endpoint khôi phục về `1`.
- Khóa dịch vụ bằng `IsLocked`.
- `ExpiredDate = null` là không giới hạn.
- Nếu API nhận ngày hết hạn `2027-01-01`, DB lưu `2026-12-31 23:59:59` giờ Việt Nam và chặn từ `2027-01-01 00:00:00`.
- User thuộc Company bị khóa/hết hạn nhận `401` ngay ở request tiếp theo, kể cả JWT cũ.
- ADMIN vẫn được truy cập để quản trị.
- Logo cho phép JPG/JPEG/PNG/WEBP, tối đa 5 MB.

Ngoài thao tác tạo bị hardcode ADMIN-only, các endpoint sửa/khóa/hạn/logo/xóa/khôi phục còn phụ thuộc ActiveKey `QLCT` và data scope. Tài khoản `CONGTY` có quyền tương ứng có thể thao tác Company của chính mình. Nếu nghiệp vụ cuối cùng muốn một số thao tác chỉ ADMIN, cần siết thêm ở service.

Logo hiện lưu local filesystem. Cách này phù hợp development một instance nhưng chưa phù hợp production nhiều instance nếu chưa chuyển sang storage dùng chung.

## 14. Quản lý Trạm

### Endpoint

- `GET /api/branches`.
- `GET /api/branches/{id}`.
- `POST /api/branches`.
- `PUT /api/branches/{id}`.
- `DELETE /api/branches/{id}`.
- `POST /api/branches/{id}/restore`.

### Danh sách và scope

- Mặc định `pageSize = 10`.
- Search trên toàn bộ dữ liệu trước khi phân trang.
- Lọc theo `companyId`, `typeTram` và `status`.
- `typeTram = 1`: trạm trộn; `typeTram = 2`: trạm cân.
- Danh sách chỉ trả `id`, `name`, `phone` và `typeTram`.
- ADMIN xem toàn hệ thống.
- CONGTY xem các trạm thuộc công ty.
- Role thấp hơn chỉ xem các BranchId được gán.
- Chỉ ADMIN xem danh sách `Status = 99`.

### Tạo, sửa, xóa và khôi phục

- Chỉ ADMIN được tạo trạm.
- Chỉ ADMIN được xóa mềm và khôi phục trạm.
- ADMIN được sửa toàn bộ trường trong request.
- CONGTY có bit Cập nhật được sửa `code`, `name`, `email`, `phone`, `address`, `pmqlXe` và `qlCamera`.
- CONGTY không được sửa `companyId`, `typeTram`, `username` hoặc `password`; backend bỏ qua các trường này nếu gửi lên.
- Role thấp hơn CONGTY không được sửa trạm dù có bit Cập nhật `QLTT`.
- Company phải active khi tạo/chuyển trạm.
- Code Branch phân biệt hoa/thường và duy nhất giữa Branch active.
- Username Branch không phân biệt hoa/thường và duy nhất giữa Branch active.
- Khôi phục kiểm tra lại Code và Username.
- Response chỉ trả mật khẩu dạng che `••••••••`.

Các trường bắt buộc khi tạo:

- `companyId`.
- `code`.
- `name`.
- `email`.
- `phone`.
- `username`.
- `password`.
- `typeTram`.

`address`, `pmqlXe` và `qlCamera` được để trống.

Lưu ý bảo mật: password trong bảng Branch đang được backend ghi theo đúng giá trị legacy gửi lên và không dùng công thức hash User. API không trả mật khẩu thật nhưng cần đánh giá lại cách lưu trước production nếu website/trạm cho phép thay đổi cơ chế này.

`Branch.Dataname` hiện chỉ được map ở entity, chưa expose qua API và chưa được dùng để mở connection tới database vận hành.

## 15. Trạng thái danh mục Function của website

Đối chiếu read-only với `dangnhap.net` ngày 30/07/2026:

| Code | Tên trên web | Status | Backend |
|---|---|---:|---|
| `QLHT` | Hệ thống | 1 | Root/container đã hỗ trợ |
| `QLCN` | Chức năng | 1 | Đã làm |
| `QLQ` | Phân quyền | 1 | Đã làm |
| `QLND` | Người dùng | 1 | Đã làm |
| `QLCT` | Quản lý công ty | 1 | Đã làm |
| `QLTT` | Quản lý trạm | 1 | Đã làm |
| `BCDH` | Báo cáo đơn hàng | 1 | Chưa làm |
| `TKĐH` | Thống kê đơn hàng | 1 | Chưa làm |
| `QLX` | Phần mềm quản lý xe | 1 | Chưa làm |
| `QLCAM` | Quản lý camera | 1 | Chưa làm |
| `QLCP` | Quản lý cấp phối | 1 | Chưa làm |
| `QLKHO` | Quản lý vật liệu | 1 | Chưa làm |
| `TKTC` | Quản lý cân ô tô | 1 | Chưa làm |
| `INPHIEU` | In phiếu | 1 | Chưa làm |
| `BC` | Báo cáo | 99 | Chưa ưu tiên |
| `QLTVL` | Quản lý trạm vật liệu | 99 | Chưa ưu tiên |
| `QLAB` | About | 99 | Chưa ưu tiên |

Mục đề xuất tiếp theo là `BCDH - Báo cáo đơn hàng` vì `dangnhap.net` đã có các bảng `Order`, `OrderItem` và `OrderTram`. Vẫn phải khảo sát schema, dữ liệu mẫu, quyền và giao diện web trước khi code.

## 16. Các phần chưa làm hoặc cần chốt lại

### Nghiệp vụ

- Chưa triển khai tám Function web active được liệt kê ở trên.
- Chưa làm Dashboard tổng hợp công ty/trạm.
- Chưa đọc sản lượng từ database vận hành tại trạm.
- Chưa xác nhận chính thức cách website dùng `Branch.Dataname` để kết nối database trạm.
- Chưa kiểm tra parity 100% giữa tất cả thao tác Company/Branch trên API và website thực tế.
- Cần chốt có giữ API khóa/mở khóa User con hay chỉ dùng xóa mềm.
- Cần chốt endpoint Company nào phải hardcode ADMIN-only ngoài thao tác tạo.
- Cần đánh giá lại cách lưu password Branch.

### Kỹ thuật và production

- Chưa có Refresh Token.
- Chưa có rate limiting cho login/API.
- Chưa có production hosting, reverse proxy, HTTPS certificate hoặc CI/CD.
- Chưa cấu hình logging/monitoring tập trung, tracing hoặc crash reporting.
- Logo vẫn lưu local filesystem.
- Timezone nghiệp vụ đang cố định UTC+7 bằng code; cần xác minh môi trường production.
- Không có cơ chế migrate toàn bộ database web; backend map trực tiếp schema hiện hữu.
- Không tự tạo foreign key hoặc unique index còn thiếu trong schema legacy.
- Cần chạy NuGet vulnerability audit lại trên máy có mạng trước production.

## 17. Giới hạn và rủi ro dữ liệu legacy

- Schema thiếu một số foreign key vật lý cho Role/assignment/parent Function; service kiểm tra trước khi ghi.
- Không có đủ unique index cho username và assignment; service chủ động chống trùng ở luồng API.
- Các hệ thống khác ghi thẳng database vẫn có thể tạo dữ liệu không hợp lệ nếu bỏ qua API.
- MD5 legacy không an toàn cho hệ thống mới nhưng hiện cần để app và web đăng nhập chung.
- `datetime` legacy không có timezone; backend đang hiểu là giờ Việt Nam và trả UTC.
- E2E cleanup bằng xóa mềm nên database dev có thể tích lũy bản ghi `E2E_*` có `Status = 99`.
- Không tự sửa dữ liệu legacy chéo Company đã phát hiện.

## 18. Script database và E2E

### So sánh schema auth/RBAC

~~~powershell
.\scripts\compare-auth-schema.ps1
~~~

So sánh read-only năm bảng giữa `dangnhap.net` và `TTSmartMobile_Dev`.

### Profile dữ liệu dev

~~~powershell
sqlcmd -S .\SQLEXPRESS `
  -E `
  -d master `
  -b -W -s "|" `
  -v DatabaseName="TTSmartMobile_Dev" `
  -i .\scripts\profile-auth-data.sql
~~~

Kiểm tra trạng thái, orphan, assignment trùng, Type và ActiveKey bất thường.

### SQL Server E2E

~~~powershell
.\scripts\run-auth-e2e.ps1 -BootstrapAdmin -StartApi
~~~

Runner:

- Chỉ cho phép `TTSmartMobile_Dev`.
- Tạo bootstrap admin tạm nếu dùng `-BootstrapAdmin`.
- Kiểm tra Auth, logout, password, User/RBAC, Company, Branch, scope, quota và ActiveKey.
- Cleanup dữ liệu test trong `finally` bằng xóa mềm.
- Không cần biết mật khẩu admin legacy khi dùng bootstrap admin.

Nếu API đã chạy ở cổng 5052 thì bỏ `-StartApi`.

## 19. Build, test và format

~~~powershell
dotnet restore .\TTSmart.sln
dotnet build .\TTSmart.sln -c Release --no-restore
dotnet test .\TTSmart.sln -c Release --no-restore
dotnet format .\TTSmart.sln --verify-no-changes --no-restore
~~~

Kết quả gần nhất ngày 30/07/2026:

~~~text
Unit + integration test: 68/68 PASS
Build Release: 0 warning, 0 error
Format verify: PASS
SQL Server E2E: PASS
~~~

Test InMemory/WebApplicationFactory không thay thế SQL E2E vì một số hành vi collation, transaction và SQL translation chỉ xuất hiện trên SQL Server thật.

## 20. Tài liệu liên quan

- `AGENTS.md`: quy tắc bắt buộc khi agent làm backend.
- `IMPLEMENTATION_REPORT.md`: báo cáo triển khai theo thời điểm.
- `BACKEND_ISSUES.md`: giới hạn schema và rủi ro legacy.
- `docs/RBAC_API_CONTRACT.md`: contract Auth/User/Role/Function.
- `docs/RBAC_PERMISSION_MATRIX.md`: mapping ActiveKey và endpoint.
- `docs/RBAC_SCHEMA_MAPPING.md`: mapping EF Core với SQL Server.
- `docs/COMPANY_API_CONTRACT.md`: contract Company.
- `docs/BRANCH_API_CONTRACT.md`: contract Branch.
- `docs/USER_BRANCH_SCOPE_DISCOVERY.md`: khảo sát User.CompanyId/User.BranchId.

Nếu contract thay đổi, phải cập nhật đồng thời code, OpenAPI, test và tài liệu tương ứng.

## 21. Checklist trước khi đổi máy

1. Chạy `git status --short` và đảm bảo mọi file cần thiết đã commit/push hoặc được sao lưu.
2. Kiểm tra cả file untracked trong kết quả `git status --short`; commit/push hoặc sao lưu riêng nếu cần giữ.
3. Backup `TTSmartMobile_Dev` bằng SQL Server và kiểm tra file backup restore được.
4. Nếu cần giữ bản tham chiếu local, backup riêng `dangnhap.net` nhưng tuyệt đối không dùng làm database dev ghi dữ liệu.
5. Copy `src/TTSmart.Api/uploads/company-logos/` nếu cần giữ logo local.
6. Ghi lại tên SQL Server instance trên máy mới; không ghi password/secret vào repository.
7. Cấu hình lại `Jwt:SigningKey` bằng User Secrets hoặc biến môi trường.
8. Restore database, kiểm tra `Company.IsLocked` và connection string.
9. Chạy build, test, format, schema compare và E2E.
10. Chỉ bắt đầu code tiếp khi toàn bộ baseline trên máy mới chạy thành công.

## 22. Quy tắc an toàn bắt buộc

- Không ghi vào `dangnhap.net`.
- Không chạy migration, `EnsureCreated` hoặc seed lên database hiện hữu.
- Không trả `Password`, `KeyLock` hoặc hash User qua API.
- Không log token, secret, connection string hoặc mật khẩu.
- Không tin `companyId`/`branchId` do mobile gửi lên nếu chưa kiểm tra data scope.
- Không đưa secret production vào `appsettings*.json` hoặc `launchSettings.json`.
- Không tự kết nối database trạm theo `Dataname` khi chưa xác nhận kiến trúc.
- Trước production phải dùng HTTPS, secret manager phù hợp, backup và kế hoạch rollback.
