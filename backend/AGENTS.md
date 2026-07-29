# Hướng Dẫn Agent Backend TTSmartApp

## 1. Mục Tiêu

- Xây dựng backend ASP.NET Core cho ứng dụng mobile nội bộ của công ty.
- Phạm vi ưu tiên hiện tại là quản lý tập trung nhiều trạm trộn, xem dữ liệu tổng hợp toàn công ty và theo dõi chi tiết từng trạm.
- Khả năng triển khai cho người quản lý một trạm tự theo dõi trạm của mình là hướng mở rộng sau này; không xây trước chế độ một trạm hoặc cơ chế đồng bộ riêng khi chưa được yêu cầu.
- Database `dangnhap.net` là bản clone local từ database website hiện tại và là nguồn tham chiếu kỹ thuật chuẩn; database làm việc cho phát triển là `TTSmartMobile_Dev`, còn app và website production sẽ dùng chung database web khi triển khai.
- Database SQL Server hiện có là nền cấu trúc ban đầu; nghiệp vụ được xác nhận dần từ người dùng, schema, database object, dữ liệu hợp lệ và website khi có thể đối chiếu.
- Không biến một module thử nghiệm hoặc giả định của phân hệ trước thành kiến trúc mặc định cho toàn hệ thống.
- Hoàn thành từng luồng có giá trị thực tế trước khi mở rộng sang nhiều bảng hoặc nhiều module cùng lúc.

## 2. Phạm Vi Trách Nhiệm

- Chịu trách nhiệm C#, ASP.NET Core Web API, EF Core, SQL Server, authentication, authorization, validation, nghiệp vụ backend, OpenAPI và test backend.
- Làm việc chủ yếu trong `backend/`; người khác phụ trách Flutter trong `../mobile/`.
- Không sửa mã mobile nếu người dùng chưa yêu cầu thay đổi xuyên dự án.
- Khi API contract thay đổi, phải mô tả rõ để người phụ trách mobile cập nhật DTO, repository, state và giao diện.
- Chỉ thay đổi đúng phân hệ được yêu cầu; không tự triển khai toàn bộ hệ thống từ tên bảng hoặc suy đoán.

## 3. Quan Hệ Với Hướng Dẫn Tổng

- Luôn đọc và tuân thủ `D:\TTSmartApp\AGENTS.md` trước khi sửa backend.
- File này chuyên biệt hóa hướng dẫn tổng cho toàn bộ cây thư mục `backend/`.
- Yêu cầu trực tiếp của người dùng có ưu tiên cao nhất.
- Khi phát hiện cấu trúc, lệnh kiểm tra hoặc quy tắc bền vững thay đổi, cập nhật file này trong cùng phạm vi công việc.

## 4. Trạng Thái Kiến Trúc Hiện Tại

- Solution hiện vẫn có tên lịch sử `TTSmart.sln`; không suy ra rằng toàn dự án chỉ quản lý nhân viên.
- API nằm tại `src/TTSmart.Api` và test nằm tại `tests/TTSmart.Api.Tests`.
- `dangnhap.net` là bản clone local từ database web hiện tại và là nguồn tham chiếu kỹ thuật chuẩn cho backend; không dùng database này làm đích ghi trong quá trình phát triển.
- `TTSmartMobile_Dev` là database làm việc dành cho phát triển, kiểm thử và các thao tác ghi của backend; phải được clone an toàn từ `dangnhap.net`.
- Khi triển khai production, website và app mobile sẽ cùng kết nối database web dùng chung; không tạo một database nghiệp vụ riêng cho app và không xây cơ chế đồng bộ thay cho việc dùng chung nguồn dữ liệu.
- Connection string backend dùng khóa tập trung `ConnectionStrings:AuthConnection`; khi đổi môi trường chỉ thay giá trị cấu hình hoặc biến môi trường `ConnectionStrings__AuthConnection`, không hardcode database trong controller/service.
- Backend đã map năm bảng web `User`, `Role`, `UserRole`, `Function`, `FunctionRole` bằng `WebAuthDbContext`; `FunctionParentId` là `int NOT NULL`, root lưu `0` và API trả `null`; không dùng mô hình cũ `[User]`, `User_Role`, `Role_Function`.
- Đã xác minh trong schema/data discovery: `FunctionRole.Type = 2` là assignment theo Role, `FunctionRole.TargetId = Role.RoleId`, còn `FunctionRole.FunctionId` có foreign key tới `Function.FunctionId`; `UserRole.UserId` có foreign key tới `User.UserId`, các liên kết Role là logic.
- API auth, User CRUD, Role CRUD, Function CRUD, cây Function, ma trận quyền và xóa mềm FunctionRole đã chuyển sang ID int và ActiveKey 9 bit; contract Flutter nằm tại `docs/RBAC_API_CONTRACT.md`, mapping schema tại `docs/RBAC_SCHEMA_MAPPING.md`.
- `ActiveKey` là chuỗi đúng 9 ký tự theo thứ tự web: Xem, Tạo mới, Cập nhật, Xóa, Nhập, Xuất, In, Khác, D.Sách. Checkbox `Đầy đủ` chỉ là trạng thái tổng hợp và tương đương `111111111`, không phải ký tự thứ 10.
- Contract chính thức cho Flutter nằm ở `docs/RBAC_API_CONTRACT.md`; `docs/mobile-access-management-api.md` chỉ giữ vai trò redirect tương thích.
- Module `Employees` demo và các mapping auth cũ chỉ là lịch sử/thử nghiệm; không dùng làm nền mặc định cho schema web mới.

## 5. Cấu Trúc Dự Án Và Hướng Phụ Thuộc

### 5.1. Bố Cục Chuẩn

```text
backend/
├─ TTSmart.sln
├─ src/TTSmart.Api/
│  ├─ Controllers/              # HTTP boundary, binding, status code
│  ├─ Features/                 # module, contract, service, authorization
│  ├─ Data/                     # EF Core DbContext, entity, mapping legacy
│  ├─ Common/                   # thành phần dùng chung thật sự
│  ├─ Properties/               # launch settings, assembly metadata
│  ├─ Program.cs                # composition root và pipeline
│  └─ appsettings*.json         # cấu hình không chứa secret
├─ tests/TTSmart.Api.Tests/     # unit, service, HTTP integration
├─ docs/                        # contract, mapping, report đã xác nhận
├─ scripts/                     # discovery, profile, E2E, verify có tên rõ hành động
├─ skills/                      # hướng dẫn agent chuyên backend
├─ database/                    # artifact/schema script được kiểm soát, không chứa secret
└─ backups/                     # backup được xác nhận, không dùng làm source code
```

- Hiện tại một API project và một test project là phù hợp với phạm vi Auth/RBAC, Company và Branch; không tách class library, project nghiệp vụ hoặc Generic Repository chỉ để tạo nhiều tầng.
- `Controllers/` chỉ nhận request, gọi feature service và trả response; không đặt truy vấn EF Core, transaction hoặc quy tắc nghiệp vụ trong controller.
- `Features/<TênPhânHệ>/` là nơi chứa contract, service, interface, validation và helper thuộc use case. Phân hệ hiện tại gồm `Auth`, `Authorization`, `AccessManagement`, `CompanyManagement` và `BranchManagement`.
- `Data/WebAuth/` chỉ map năm bảng auth/RBAC legacy; không đưa toàn bộ database công ty vào một `DbContext` duy nhất.
- `Common/` chỉ chứa exception, model, security hoặc OpenAPI dùng chung và không được trở thành nơi gom logic chưa xác định thuộc feature nào.
- `Program.cs` là composition root: đăng ký dependency injection, authentication/authorization, middleware và pipeline. Khi module tăng rõ rệt, có thể tách extension đăng ký theo module; chưa tách chỉ vì file hiện tại dài.
- `docs/`, `scripts/` và `skills/` là phần bàn giao của backend, không đặt logic runtime vào đây. Log chạy thử phải nằm trong artifact/temp đã ignore, không để làm source of truth ở root.

### 5.2. Hướng Phụ Thuộc

```text
Controller -> Feature service -> Data/DbContext
                  └──────────-> Common
Program ----------------------> tất cả module để composition
Tests -------------------------> API public/contract và test fixture
```

- `Data` không phụ thuộc `Controllers` hoặc response DTO.
- Entity EF Core không trả trực tiếp ra API; feature map entity sang request/response DTO.
- `Features` được gọi qua interface/service rõ ràng; không để feature này truy cập state nội bộ của feature khác.
- `Common` không phụ thuộc ngược vào feature cụ thể; nếu một helper chỉ phục vụ một module, đặt nó trong module đó.
- Không tạo circular dependency, import vào file nội bộ của feature khác hoặc duplicate DTO chỉ khác tên.
- Khi cần transaction xuyên module, xác định rõ owner của use case và lý do trước khi dùng chung `DbContext`; không dùng static state hoặc service locator.

### 5.3. Quy Tắc Mở Rộng Module

- Module mới bắt đầu bằng `Features/<Module>/`, controller tương ứng, mapping tối thiểu trong `Data/<Module>/` hoặc context đã được xác nhận, contract riêng và test riêng.
- Nếu một feature có nhiều tài nguyên độc lập, tách dần theo `Users/`, `Roles/`, `Functions/` hoặc file theo resource khi việc tách giúp giảm trách nhiệm và conflict; không đổi tên hàng loạt chỉ để đồng bộ hình thức.
- `AccessManagementContracts.cs` và các service User/Role/Function hiện đang gom trong một phân hệ vì cùng use case RBAC. Trước khi thêm nghiệp vụ lớn, cần tách contract/test theo User, Role và Function để tránh file trung tâm phình to.
- `RoleAdministrationService`, `UserAdministrationService` và `FunctionAdministrationService` hiện đã lớn nhưng vẫn có ranh giới resource rõ; ưu tiên tách helper/query/validator khi trách nhiệm mới xuất hiện, không chia nhỏ máy móc theo số dòng.
- `WebAuthDbContext` tiếp tục chỉ map năm bảng auth/RBAC legacy. `CompanyDbContext` map tối thiểu `Company` và `Branch` cho các module đã xác nhận; module nghiệp vụ mới phải khảo sát schema trước và chỉ thêm mapping tối thiểu, dùng context/configuration riêng nếu ranh giới dữ liệu hoặc vòng đời khác nhau.
- Không dùng migration, seeder hoặc `EnsureCreated` cho database clone công ty; thay đổi schema phải có script, đánh giá website dùng chung và kế hoạch rollback riêng.

### 5.4. Tổ Chức Test Và Tài Liệu

- Test unit/pure logic đặt theo class hoặc behavior; test service đặt theo feature; HTTP integration test kiểm tra contract và pipeline; SQL E2E kiểm tra translation, collation, transaction và dữ liệu clone.
- Khi module tăng, không để một file test chứa toàn bộ User/Role/Function; tách theo resource nhưng vẫn giữ tên phản ánh use case.
- Mỗi breaking change phải cập nhật contract trong `docs/`, OpenAPI/test liên quan và ghi rõ thay đổi cho Flutter.
- Script có khả năng ghi dữ liệu phải xác minh database đích, có prefix/cleanup và tên thể hiện hành động; không lưu output một lần vào thư mục tài liệu chính thức.

### 5.5. Tự Đánh Giá Cấu Trúc Hiện Tại

- **Đạt:** một solution nhỏ, feature-based, controller mỏng, mapping database tách khỏi API, có test unit/integration/E2E, contract và script đối chiếu rõ ràng.
- **Đạt:** không có Generic Repository, MediatR hoặc class library thừa; phù hợp giai đoạn backend đã có Auth/RBAC, Company và Branch.
- **Cần theo dõi:** `Program.cs` đang kiêm nhiều đăng ký hạ tầng và policy; chỉ tách composition extension khi có thêm module hoặc policy khiến việc đọc/kiểm tra khó khăn.
- **Cần theo dõi:** AccessManagement contracts/service/test đang lớn; trước phân hệ nghiệp vụ tiếp theo nên chia theo resource nếu tiếp tục tăng.
- **Cần theo dõi:** artifact `*.log` ở root dù đã bị ignore; không đưa log runtime vào commit và nên xóa/move khi hoàn tất điều tra.
- **Kết luận:** chưa cần refactor cấu trúc ngay. Cấu trúc hiện tại đủ tốt để triển khai module tiếp theo; các quy tắc trên là guardrail để mở rộng mà không biến `Program.cs`, `AccessManagement` hoặc `WebAuthDbContext` thành điểm gom toàn hệ thống.

### 5.6. Chuẩn Bắt Buộc Khi Thêm Và Bàn Giao Module

- Mỗi module mới phải có một tên nghiệp vụ rõ ràng và một vị trí chính duy nhất trong `Features/<Module>/`; không rải contract, query và business rule của cùng module ở nhiều thư mục không liên quan.
- Cấu trúc tham khảo cho một module có CRUD hoặc workflow độc lập:

```text
src/TTSmart.Api/
├─ Controllers/<Resources>Controller.cs
├─ Features/<Module>/
│  ├─ <Module>Contracts.cs
│  ├─ I<Module>Service.cs
│  ├─ <Module>Service.cs
│  └─ <Module>Support.cs          # chỉ tạo khi có helper riêng thật sự
└─ Data/<Module>/
   ├─ <Module>DbContext.cs       # chỉ khi cần context riêng
   ├─ <Module>Entities.cs
   └─ <Module>Configurations.cs

tests/TTSmart.Api.Tests/
├─ <Module>ServiceTests.cs
└─ <Module>ApiTests.cs           # khi cần kiểm tra HTTP contract

docs/<module>-api-contract.md
scripts/<động-từ>-<module>.*     # chỉ khi cần discovery/profile/E2E SQL
```

- Đây là cấu trúc định hướng, không bắt buộc tạo file rỗng hoặc đủ mọi file. Chỉ tạo thành phần có trách nhiệm thật và giữ tên nhất quán với resource/API đang triển khai.
- Một controller không được trở thành nơi chứa nghiệp vụ; một service không được kiêm nhiều module; một `Contracts.cs` không được tiếp tục nhận DTO của các phân hệ không liên quan.
- Query phức tạp, validation nghiệp vụ và transaction phải có owner rõ trong module. Helper chỉ dùng cho một module phải nằm trong module, không đẩy vào `Common` để giảm số file.
- Khi module lớn dần, tách theo resource hoặc use case trước khi file trở thành điểm conflict thường xuyên; không chờ đến khi toàn bộ module phải refactor cùng lúc.
- Mỗi module phải có test tối thiểu cho success, validation, not found/conflict, authorization và hành vi SQL quan trọng; không bàn giao module chỉ có controller/service mà không có test phù hợp.
- Mỗi module phải có contract cho mobile hoặc cập nhật tài liệu contract hiện có, gồm route, request, response, phân trang/filter, quyền, mã lỗi và dữ liệu mẫu đã ẩn danh.
- Khi bàn giao, phải chỉ ra đường đọc code theo thứ tự: controller/endpoint → contract → service/use case → entity/mapping/database object → authorization → test → script E2E.
- Báo cáo bàn giao phải liệt kê file tạo/sửa, bảng/view/procedure/trigger sử dụng, giả định nghiệp vụ, thay đổi API, dữ liệu test/cleanup và lệnh kiểm tra đã chạy.
- Một module chỉ được coi là hoàn thành khi người tiếp nhận có thể tìm entry point, hiểu luồng dữ liệu và chạy test từ tên thư mục/file mà không cần dựa vào lịch sử hội thoại của agent trước.

## 6. Nguồn Sự Thật Cho Nghiệp Vụ

Khi phân tích một chức năng, ưu tiên theo thứ tự:

1. Yêu cầu và xác nhận trực tiếp của người dùng.
2. Schema, constraint, quan hệ, dữ liệu hợp lệ, view, stored procedure, function, trigger và computed column trong `dangnhap.net`; mọi thao tác phát triển hoặc kiểm thử có ghi dữ liệu phải thực hiện trên `TTSmartMobile_Dev`.
3. API contract, code, test và tài liệu đã được xác nhận trong repository.
4. Hành vi thực tế của website công ty nếu có thể quan sát hoặc được cung cấp tài liệu, chỉ dùng làm nguồn tham khảo và đối chiếu.
5. Giả định tạm thời của agent, phải được ghi rõ khi bàn giao.

- Database không tự mô tả đầy đủ quy trình nghiệp vụ, ý nghĩa trạng thái, quyền thao tác hoặc công thức tính.
- `dangnhap.net` là chuẩn kỹ thuật từ website nhưng không phải đích ghi của backend dev; không dùng dữ liệu đã thay đổi trên `TTSmartMobile_Dev` để suy ngược rằng website production cũng có hành vi đó.
- View, stored procedure, function, trigger và quy tắc cũ là bằng chứng để phân tích, không tự động là nghiệp vụ bắt buộc của app mới.
- Không tuyên bố chức năng đã giống website nếu chưa đối chiếu hành vi web hoặc chưa được người dùng xác nhận.
- Khi website, database và yêu cầu mâu thuẫn, nêu rõ mâu thuẫn và phương án đang áp dụng; không âm thầm chọn một nguồn.

## 7. Quy Tắc Database-First

- Không thêm, xóa hoặc đổi tên bảng, cột hay database object để phục vụ app mobile, ngoại trừ cột `Company.IsLocked` đã được người dùng phê duyệt riêng cho nghiệp vụ khóa công ty. Backend phải xây dựng trên các bảng, cột và quan hệ hiện có cùng ngoại lệ duy nhất này.
- `Company.IsLocked` dùng kiểu `bit`, không null, mặc định `0`; `0` là không khóa và `1` là khóa thủ công toàn bộ tài khoản thuộc công ty. Cột này do backend mobile sử dụng trước; website chưa kiểm tra khóa và sẽ được cập nhật riêng sau.
- Danh sách quản trị công ty trên mobile của `ADMIN` vẫn phải trả cả công ty đang khóa, kèm `isLocked` và thao tác mở khóa. Website hiện chưa hiển thị hoặc xử lý trạng thái khóa này.
- Trong màn hình Quản lý công ty trên mobile, mặc định chỉ hiển thị công ty có `Company.Status = 1`. Khi `ADMIN` mở bộ lọc, có thể chọn xem công ty xóa mềm `Company.Status = 99`; các công ty này có thao tác khôi phục về `Status = 1`. Khôi phục chỉ thay đổi `Status`; `IsLocked`, `ExpiredDate` và các dữ liệu liên quan giữ nguyên để tiếp tục được đánh giá theo quy tắc hiệu lực hiện hành. Website hiện chưa có bộ lọc hoặc nút khôi phục này.
- Trong màn hình Quản lý tài khoản User trên mobile, mặc định chỉ hiển thị User có `User.Status = 1`. Khi người có quyền mở bộ lọc, có thể xem User xóa mềm `User.Status = 99` và dùng thao tác khôi phục về `Status = 1`; khôi phục không tự thay đổi role, CompanyId, BranchId hoặc thông tin khác. `ADMIN` được khôi phục User theo phạm vi toàn hệ thống; `CONGTY` chỉ được khôi phục tài khoản role thấp hơn thuộc đúng CompanyId của mình, không được khôi phục role ngang cấp. Website hiện chưa có bộ lọc hoặc nút khôi phục này.
- Role `ADMIN` là super admin toàn hệ thống. Mọi chức năng backend/mobile mà hệ thống cung cấp cho `ADMIN` không bị giới hạn bởi `FunctionRole.ActiveKey`, phạm vi công ty/trạm, `Company.IsLocked`, `Company.ExpiredDate`, quota tài khoản, cấp bậc role hoặc trạng thái dịch vụ của công ty. Quy tắc bỏ qua phải được triển khai tập trung, không rải điều kiện theo controller. `ADMIN` vẫn phải đăng nhập hợp lệ, có `User.Status = 1`, tuân thủ validation, tính toàn vẹn dữ liệu và các ràng buộc kỹ thuật bắt buộc.
- `Company.Active` tiếp tục giữ nguyên ý nghĩa miễn phí/trả phí của website: `0` là miễn phí, `1` là trả phí; không được dùng làm cờ khóa tài khoản trong backend mobile.
- `Company.ExpiredDate` chưa có giao diện và chưa tự khóa trên website đang chạy. Web beta mới có ô “Thời gian đến hạn” và nút Lưu riêng trên danh sách, không đặt trong form tạo/sửa Company. Mobile/backend kế thừa hướng mới này bằng endpoint cập nhật hạn riêng; để trống lưu `NULL`, giao diện hiển thị `dd/MM/yyyy`, còn API nhận ngày thuần `yyyy-MM-dd`.
- Logo Company trên mobile được tải file lên backend bằng endpoint riêng, không gửi base64 hoặc URL trong request tạo/sửa. Dữ liệu legacy đang lưu tên file trong `Company.Logo`, vì vậy backend tiếp tục lưu tên file đã chuẩn hóa và quản lý file vật lý; nếu đổi sang storage khác sau này thì giữ contract upload ổn định.
- Logo upload chỉ nhận `JPG`, `JPEG`, `PNG`, `WEBP`, dung lượng tối đa `5 MB`; backend phải kiểm tra cả phần mở rộng và content type, không tin tên file từ client.
- `Company.Code` là mã công ty và `Branch.Code` là mã trạm. Cả hai được trim khoảng trắng đầu/cuối nhưng phân biệt chữ hoa/thường; ví dụ `dacdao` và `DacDao` là hai mã khác nhau.
- Mã chỉ cần duy nhất giữa các bản ghi cùng bảng có `Status = 1`; mã của bản ghi `Status = 99` được phép sử dụng lại. Tạo hoặc đổi sang mã trùng chính xác với bản ghi đang hoạt động phải trả `409 Conflict`; không thêm unique index/constraint vào database để thực hiện quy tắc này.
- `Branch.Username` phải duy nhất giữa các Branch có `Status = 1`; username của Branch `Status = 99` được phép sử dụng lại. Backend phải kiểm tra trùng khi tạo/sửa trong transaction và trả `409 Conflict`; không thêm unique index/constraint vào database. Các username trùng hiện có trong dữ liệu `Status = 99` phải được giữ nguyên.
- Validation `Company.Code` đã được triển khai trong CompanyManagement. Module/API Branch đã được triển khai bước đầu tại `Features/BranchManagement`, `Controllers/BranchesController.cs` và mapping `CompanyDbContext.Branches`; contract mobile nằm tại `docs/BRANCH_API_CONTRACT.md`. Mọi mở rộng tiếp theo phải giữ đúng actor, TypeTram, phạm vi CompanyId, `User.BranchId` và quyền `QLTT` đã chốt.
- `Branch.TypeTram = 1` là trạm trộn; `Branch.TypeTram = 2` là trạm cân. Hai loại trạm thuộc các màn hình/nghiệp vụ khác nhau; trang tổng quan ưu tiên trạm trộn, còn trạm cân được xử lý ở trang riêng. Không tự gộp hai loại trong một response hoặc use case nếu contract chưa yêu cầu.
- Khi tạo Branch/trạm, `ADMIN` được phép chọn một trong hai loại `TypeTram = 1` hoặc `TypeTram = 2`; backend phải validate chỉ nhận hai giá trị này. `CONGTY` không được tạo trạm và không được thay đổi `TypeTram` của trạm hiện có.
- Khi `ADMIN` tạo Branch/trạm, các trường bắt buộc gồm `CompanyId`, `Code`, `Name`, `Email`, `Phone`, `Username`, `Password` và `TypeTram`. Chỉ `Address`, `PMQLXe` và `QLCamera` được phép để trống; `BranchId` là khóa do hệ thống/database tạo, không phải trường nhập bắt buộc từ client.
- `Branch.Password` không được trả nguyên văn trong response API. Nếu contract cần hiển thị giống web, response chỉ trả giá trị masked như `••••••••` hoặc cờ masked để mobile render bằng input kiểu password; giá trị masked không được gửi ngược lên làm mật khẩu mới. Khi cập nhật, chỉ ghi mật khẩu mới khi client chủ động nhập giá trị mới; nếu để masked/không đổi thì giữ nguyên dữ liệu database.
- Mật khẩu Branch khi `ADMIN` tạo mới hoặc thay đổi phải giữ tương thích validation legacy của web: chứa ít nhất một chữ thường `a-z`, một chữ hoa `A-Z`, một chữ số `0-9` và một ký tự đặc biệt thuộc nhóm `@#$%`. Web hiện không xác nhận giới hạn độ dài, nhưng app/backend bắt buộc tối thiểu 8 ký tự cho mật khẩu mới; không được hạ mức này khi tạo hoặc đổi mật khẩu từ mobile.
- Danh sách công ty để chọn khi tạo Branch/trạm chỉ hiển thị Company có `Company.Status = 1`. Backend phải kiểm tra lại `CompanyId` trong transaction và từ chối tạo nếu công ty không tồn tại hoặc không có `Status = 1`; không được chỉ tin vào danh sách đã lọc từ mobile.
- Khi tạo Branch/trạm, backend tự đặt `Branch.Status = 1`, tự ghi `CreatedAt` và `UpdatedAt` theo thời gian server; mobile không được quyết định hoặc ghi đè các trường hệ thống này. Khi cập nhật, backend tự cập nhật `UpdatedAt` và giữ nguyên quy tắc trạng thái đã chốt.
- Chỉ role `ADMIN` được tạo Branch/trạm mới. `ADMIN` được sửa thông tin trạm theo phạm vi quản trị toàn hệ thống. Tài khoản `CONGTY` không được tạo trạm nhưng được sửa trạm có đúng `Branch.CompanyId` của mình và chỉ được cập nhật các trường trên form web đã xác nhận: Mã chi nhánh → `Branch.Code`, Tên chi nhánh → `Branch.Name`, Email → `Branch.Email`, Số điện thoại → `Branch.Phone`, Địa chỉ → `Branch.Address`, Phần mềm quản lý xe → `Branch.PMQLXe`, Quản lý Camera → `Branch.QLCamera`. `CONGTY` không được sửa loại trạm → `Branch.TypeTram`, tài khoản → `Branch.Username`, mật khẩu → `Branch.Password`, `CompanyId`, `Status` hoặc các cột khác ngoài danh sách được phép; role thấp hơn không được sửa trạm. Backend phải kiểm tra actor, data scope và field allowlist ở service/authorization, không phụ thuộc việc mobile ẩn hoặc khóa trường.
- Quyền sửa 7 trường được phép của `CONGTY` còn phụ thuộc Function `QLTT` và bit Cập nhật trong `FunctionRole.ActiveKey`; nếu thiếu bit Cập nhật thì chỉ được xem theo phạm vi của mình. Việc có bit Cập nhật không cho phép `CONGTY` sửa các trường bị khóa hoặc vượt `CompanyId`.
- Ở màn hình chi tiết/sửa Branch, `CONGTY` vẫn được xem loại trạm (`Branch.TypeTram`), tài khoản (`Branch.Username`) và mật khẩu ở dạng masked, nhưng ba trường này là read-only đối với `CONGTY`. Chỉ `ADMIN` được thay đổi ba trường đó; đây là giới hạn sửa trường, không phải trạng thái khóa tài khoản hoặc khóa trạm.
- Với Function `QLTT`, bit D.Sách kiểm soát quyền xem danh sách Branch/trạm và bit Xem kiểm soát quyền xem chi tiết một Branch/trạm. Có D.Sách nhưng không có Xem thì chỉ được xem danh sách; có Xem nhưng không có D.Sách thì được xem chi tiết trực tiếp nếu Branch nằm trong data scope. Đây là quy tắc hiển thị/đọc, không cấp thêm quyền tạo, sửa, xóa mềm hoặc khôi phục cho role bị giới hạn actor.
- Màn hình/API Quản lý trạm mặc định hiển thị cả Branch trạm trộn (`TypeTram = 1`) và Branch trạm cân (`TypeTram = 2`); phải hỗ trợ bộ lọc theo loại Trạm trộn hoặc Trạm cân, đồng thời vẫn áp dụng Status, Function permission và data scope của actor.
- `ADMIN` được lọc danh sách Branch theo Company; bộ lọc này không mở rộng quyền ngoài phạm vi super admin. `CONGTY` không cần và không được chọn công ty khác, chỉ xem các Branch thuộc `CompanyId` của mình. Role thấp hơn tiếp tục bị giới hạn bởi các BranchId đã gán trong `User.BranchId`.
- Danh sách Branch hỗ trợ một tham số tìm kiếm chung `search`; backend tìm theo `Branch.Code` hoặc `Branch.Name` bằng điều kiện OR. Mobile dùng một ô “Mã hoặc tên trạm”; bộ lọc Company, TypeTram và Status vẫn là các bộ lọc riêng.
- Danh sách Branch phân trang mặc định 10 bản ghi/trang. Khi có `search` hoặc bộ lọc, backend phải áp dụng điều kiện tìm kiếm/lọc trên toàn bộ dữ liệu nằm trong data scope của actor trước, sau đó mới `ORDER BY` và phân trang; không được chỉ tìm trong 10 bản ghi của trang hiện tại. API nhận `page` và `pageSize`, trong đó `pageSize` mặc định là 10.
- Thứ tự mặc định của danh sách Branch là `Branch.Name ASC`, sau đó `Branch.BranchId ASC` để bảo đảm thứ tự ổn định khi tên trùng; chưa cần cho mobile chọn kiểu sắp xếp khác nếu chưa có yêu cầu.
- API danh sách Branch hiện chỉ trả đúng ba trường hiển thị chính: tên trạm (`Branch.Name`), số điện thoại (`Branch.Phone`) và loại trạm (`Branch.TypeTram`); không thêm mã trạm, tên công ty hoặc toàn bộ cột legacy vào projection danh sách khi chưa được yêu cầu. API chi tiết mới trả đầy đủ các trường được phép xem/sửa theo actor, trong đó mật khẩu chỉ ở dạng masked và không bao giờ trả giá trị nguyên văn.
- Chỉ role `ADMIN` được xóa mềm hoặc khôi phục Branch/trạm. Xóa mềm cập nhật `Branch.Status = 99`; khôi phục cập nhật `Branch.Status = 1`. Tài khoản `CONGTY` và các role thấp hơn không được thực hiện hai thao tác này.
- Màn hình/API danh sách Branch/trạm mặc định chỉ trả bản ghi có `Branch.Status = 1`. Chỉ `ADMIN` được mở bộ lọc để xem trạm đã xóa mềm `Branch.Status = 99` và dùng thao tác khôi phục; khôi phục chỉ đổi `Status` về `1`, không tự thay đổi các trường hoặc quan hệ khác.
- Function quản lý trạm trong database là `Function.Code = QLTT`, tên `Quản lý trạm`, hiện có `FunctionId = 3057` trong bản clone nhưng code không được hardcode ID này. `ADMIN` xem toàn bộ trạm và được bỏ qua ma trận quyền theo quy tắc super admin. `CONGTY` chỉ xem trạm thuộc đúng `CompanyId` của mình. Role thấp hơn chỉ được vào chức năng/API quản lý trạm khi được cấp quyền `QLTT` tương ứng qua `FunctionRole.ActiveKey`, và khi được cấp vẫn chỉ xem các trạm nằm trong phạm vi `User.BranchId` đã gán; quyền Function không được mở rộng data scope.
- Các role thấp hơn `CONGTY` không được tạo, sửa, xóa mềm hoặc khôi phục Branch/trạm, kể cả khi `FunctionRole.ActiveKey` có bit Cập nhật, Xóa hoặc các bit thao tác tương ứng. Các bit đó không được vượt qua giới hạn actor của nghiệp vụ trạm.
- Với tài khoản không phải `ADMIN`, `Company.ExpiredDate = NULL` được coi là không giới hạn thời gian; nếu có ngày thì backend mobile tự chặn khi quá hạn theo giờ Việt Nam. Trạng thái hiệu lực kết hợp `Company.Status = 1`, `Company.IsLocked = 0` và điều kiện ngày hết hạn.
- `Company.ExpiredDate` biểu diễn mốc khóa đầu ngày đã chọn: nếu ngày hết hạn nghiệp vụ là `2027-01-01` thì DB lưu `2026-12-31 23:59:59` theo giờ Việt Nam; công ty được dùng đến hết timestamp đó và bị chặn từ `2027-01-01 00:00:00`. Backend phải giữ nguyên cách quy đổi này, không coi `2027-01-01 23:59:59` là hạn cuối của ngày `2027-01-01`.
- Ngoài `Company.IsLocked`, không tạo EF Core migration, bảng phụ, cột phiên bản, cột audit, cột phân cấp quyền, index, constraint, view, stored procedure, function hoặc trigger mới, kể cả trên `TTSmartMobile_Dev`, nếu mục đích là thay đổi hoặc mở rộng schema hiện có.
- Khi một nghiệp vụ không thể biểu diễn bằng schema hiện tại, ưu tiên dùng logic C#, cấu hình backend và dữ liệu trong các cột hiện có. Nếu vẫn không thể triển khai an toàn, phải báo rõ giới hạn để người dùng quyết định; không tự sửa schema.
- Chỉ map bảng và database object cần cho phân hệ hiện tại; không scaffold toàn bộ database vào một DbContext lớn.
- Giữ nguyên tên bảng, tên cột, typo lịch sử, kiểu dữ liệu, độ dài, precision, nullable, khóa và quan hệ của schema gốc.
- Trước khi viết logic C#, kiểm tra trigger, stored procedure, view, function, default, check constraint và computed column liên quan.
- Với bảng SQL Server có trigger được EF Core ghi dữ liệu, cấu hình `UseSqlOutputClause(false)` để tránh câu lệnh `OUTPUT` không tương thích trigger.
- Không viết lại nghiệp vụ trong C# nếu database object hiện có đã thực thi nghiệp vụ đó mà chưa đánh giá nguy cơ chạy trùng logic.
- Dùng Fluent API để map rõ khóa, column name, độ dài, kiểu SQL và relationship; không trả entity EF Core qua API.
- Dùng `AsNoTracking` và projection cho truy vấn chỉ đọc; tránh N+1 và không tải graph dữ liệu không cần thiết.
- Dùng truy vấn tham số hóa qua EF Core hoặc API SQL an toàn; không nối chuỗi SQL từ dữ liệu người dùng.
- Với stored procedure hoặc raw SQL, khai báo rõ input/output, transaction, timeout và cách xử lý result set.
- Tuyệt đối không chạy `INSERT`, `UPDATE`, `DELETE`, `ALTER`, `DROP`, EF Core migration, `EnsureCreated`, seeder, restore hoặc attach lên `dangnhap.net`.
- Không để backend Development kết nối nhầm `dangnhap.net`; mọi thao tác ghi phải hướng vào `TTSmartMobile_Dev` và connection string phải được cấu hình ngoài controller/service.
- Không tự drop, reset, restore, attach hoặc ghi đè database. Script tạo clone phải từ chối nếu database đích đã tồn tại. Luồng reset `TTSmartMobile_Dev` phải được người dùng xác nhận, backup database làm việc và xác minh backup thành công trước khi phục hồi.
- Không đề xuất hoặc thực hiện thay đổi schema như một phần triển khai thông thường ngoài ngoại lệ `Company.IsLocked`; mọi thiết kế API, authorization, data scope, khóa phiên và nghiệp vụ khác phải thích nghi với schema có sẵn.
- Dữ liệu test ghi vào `TTSmartMobile_Dev` phải có định danh rõ, được dọn sạch và không kích hoạt side effect ngoài dự kiến của trigger hoặc database object dùng chung với website.
- Với dữ liệu vận hành, phải xác định cột hoặc quan hệ phân biệt trạm trước khi mở API; không nhận mã trạm từ mobile rồi truy vấn trực tiếp nếu chưa authorization phạm vi đó.
- Giữ ranh giới dữ liệu theo trạm rõ trong DTO/service để có thể mở rộng sau này, nhưng không tự xây cơ chế nhiều database, đồng bộ hoặc triển khai riêng từng trạm.

## 8. Quy Trình Triển Khai Một Phân Hệ

1. Xác định use case nhỏ cần hoàn thành và actor sử dụng.
2. Xác định `Function`, `Role`, `UserRole`, `FunctionRole` và phạm vi dữ liệu liên quan trong hệ thống phân quyền web hiện có.
3. Khảo sát bảng chính, bảng liên kết, khóa, index, trigger, procedure và dữ liệu mẫu của phân hệ.
4. Xác định phạm vi toàn công ty hoặc từng trạm; dùng website như nguồn tham khảo cho danh sách, bộ lọc, chi tiết, tạo, sửa, duyệt, hủy và trạng thái nếu có thể đối chiếu.
5. Ghi rõ nghiệp vụ đã xác nhận, điểm chưa rõ và giả định tạm thời.
6. Chốt API contract với request, response, validation, status code, phân trang và lỗi.
7. Map tối thiểu entity/configuration cần thiết; không map bảng ngoài phạm vi.
8. Đặt truy cập dữ liệu và nghiệp vụ trong service/feature; giữ controller mỏng.
9. Áp authorization tại backend dựa trên `FunctionRole` và trường quyền đã được xác nhận; không dùng giả định `Right`/`ActiveRight` từ mô hình cũ.
10. Viết test cho luồng thành công, validation, không tìm thấy, xung đột và quyền.
11. Kiểm tra SQL thực tế, OpenAPI và E2E trên `TTSmartMobile_Dev` khi hành vi phụ thuộc SQL Server; chỉ đối chiếu read-only với `dangnhap.net` khi cần.
12. Bàn giao contract và dữ liệu mẫu đã ẩn danh cho người phụ trách mobile.

## 9. Authentication Và Authorization

- Tài khoản, vai trò, function và quyền phải được map từ đúng schema web: `User`, `Role`, `UserRole`, `Function`, `FunctionRole`.
- `User.UserId` liên kết `UserRole.UserId`; `UserRole.RoleId` liên kết `Role.RoleId`. Phải xác minh foreign key thật thay vì chỉ dựa vào diagram.
- `FunctionRole.FunctionId` liên kết `Function.FunctionId`; với `Type = 2`, `FunctionRole.TargetId` trỏ logic tới `Role.RoleId`.
- `Function.FunctionParentId` được dùng làm quan hệ cha-con logic để dựng cây menu; giá trị `0` được coi là function gốc vì database không khai báo self-FK.
- `FunctionRole.ActiveKey` là nguồn quyền đã xác nhận từ giao diện web, có đúng 9 bit theo thứ tự đã ghi ở trên; backend phải parse qua helper dùng chung, không rải magic index.
- Không tiếp tục dùng `Right`, `PosibleRight`, `ActiveRight`, `Authorization:UseActiveRight` hoặc `ILegacyActiveRightStore` làm chuẩn kiến trúc nếu các trường này không tồn tại trong schema web mới.
- Các cột `Status` trên năm bảng dùng quy ước đã xác minh từ dữ liệu: `1` là hiệu lực, `99` là ngừng hiệu lực/xóa mềm; truy vấn nghiệp vụ mặc định chỉ lấy `Status = 1`.
- Các cột `RoleLevel`, `RoleMax`, `LevelRole`, `BranchId`, `CompanyId`, `DepartmentId`, `PositionId` và `UnitId` có thể liên quan thứ bậc hoặc phạm vi dữ liệu; không bỏ qua và không tự diễn giải trước khi khảo sát.
- `UserId`, `UserEditId` trong `Role` hoặc `FunctionRole` có thể là cột audit/người sở hữu, không được coi là khóa cấp quyền trực tiếp nếu không có foreign key hoặc nghiệp vụ xác nhận.
- Mật khẩu web dùng công thức legacy hai lớp: `MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))`; hash MD5 lớp đầu phải ở dạng hex chữ thường như `ts-md5`, encoding lấy từ `AuthDatabase:PasswordWriteMode` và mặc định là `Md5Utf8`.
- `KeyLock`, `RegEmail` và `UserId` là một phần của công thức mật khẩu. Không thay đổi `KeyLock` hoặc `RegEmail` mà không đồng thời tạo lại password hash theo công thức web; endpoint cập nhật user hiện không cho đổi `RegEmail` để tránh khóa nhầm tài khoản.
- Form sửa User trên mobile map vào cột hiện có: Tên người dùng → `User.FullName`, Tài khoản → `User.UserName`, Ảnh đại diện → `User.Avata` (giữ typo legacy), Email → `User.Email`, Địa chỉ → `User.Address`, Số điện thoại → `User.Phone`, Phân quyền → `UserRole`, Trạm → `User.BranchId`. `User.Email` và `User.RegEmail` không được coi là cùng một trường; form không sửa `RegEmail`, và đổi `Email` không được làm thay đổi hash mật khẩu.
- Luồng mobile kế thừa thứ tự nghiệp vụ của web: tạo Company trước, tạo Branch thuộc Company sau đó mới tạo User. Role `CONGTY` không bắt buộc gán Branch vì được xem toàn bộ Branch của Company; các role tài khoản con khác phải được gán ít nhất một Branch hợp lệ.
- Mobile gửi mật khẩu gốc qua HTTPS tới `/api/auth/login`; backend tự mô phỏng bước MD5 frontend và bước MD5 backend của website, không yêu cầu Flutter tự băm mật khẩu.
- JWT phải kiểm tra issuer, audience, chữ ký, thời hạn và trạng thái tài khoản hiện tại trong database.
- Mobile có thể ẩn menu hoặc nút theo quyền trả về, nhưng backend vẫn phải kiểm tra authentication, function permission và data scope ở từng endpoint.
- Không hardcode quyền chỉ theo tên role hoặc claim JWT nếu database đã có ma trận quyền động.
- Phân quyền Function không thay thế data scope. Với User CRUD, ADMIN được thao tác toàn hệ thống; tài khoản khác chỉ được đọc/thao tác User cùng CompanyId, còn tài khoản chưa có CompanyId chỉ được đọc chính mình. Truy cập User ngoài scope phải trả 404.
- Khi tài khoản không phải ADMIN tạo hoặc đổi Role cho User, backend phải giữ CompanyId của actor, yêu cầu đúng một Role và không cho gán ADMIN hoặc CONGTY; không dựa vào việc mobile ẩn lựa chọn.
- Khi user có nhiều Role, backend hợp nhất quyền theo OR từng bit ActiveKey; response vẫn giữ assignment theo từng Role để mobile và quản trị đối chiếu.
- Authorization phải đọc trạng thái user và quyền hiện tại từ database hoặc có cơ chế invalidation tương đương để việc khóa tài khoản hoặc thay đổi quyền có hiệu lực đúng yêu cầu.
- Không log mật khẩu, password hash, JWT, secret hoặc payload xác thực nhạy cảm.

## 10. Quy Ước API Cho Mobile

- Dùng ASP.NET Core Controller và REST API JSON; tên thuộc tính mặc định `camelCase`.
- DTO request/response phải độc lập với entity và tên bảng SQL Server.
- Timestamp có thời gian dùng ISO 8601 và UTC; trường chỉ có ngày dùng `yyyy-MM-dd`.
- Dùng `ProblemDetails`/`ValidationProblemDetails` nhất quán và không lộ stack trace hoặc SQL nội bộ.
- Phân biệt `401 Unauthorized` cho phiên đăng nhập không hợp lệ và `403 Forbidden` cho thiếu quyền.
- Endpoint danh sách phải có thứ tự ổn định; thêm phân trang, filter và search khi dữ liệu có thể lớn.
- API dữ liệu vận hành phải thể hiện rõ phạm vi toàn công ty hoặc trạm và backend phải kiểm tra quyền truy cập chéo trạm.
- Không xóa hoặc đổi field mobile đang sử dụng nếu chưa đánh giá tương thích ngược.
- Khi breaking change là cần thiết, cập nhật OpenAPI và bàn giao rõ thay đổi cho người phụ trách mobile.

## 11. Quy Tắc Viết Code

- Target framework hiện tại là `net10.0`; bật nullable reference types và implicit usings.
- Dùng async API và truyền `CancellationToken` qua controller, service và EF Core.
- Giữ controller mỏng; không đặt truy vấn phức tạp hoặc nghiệp vụ trực tiếp trong controller.
- Không thêm Generic Repository, MediatR, AutoMapper hoặc nhiều tầng kiến trúc nếu chưa có nhu cầu thật.
- Ưu tiên module theo `Features/<TênPhânHệ>` cùng configuration và service rõ ràng.
- Validation trải nghiệm ở mobile không thay thế validation và bảo toàn dữ liệu ở backend.
- Không để placeholder, TODO, method chưa hoàn thiện hoặc code bị comment thay cho logic thật.
- Không sửa warning, test hoặc module không liên quan đến yêu cầu hiện tại.

## 12. Skill Bắt Buộc

- Trước mọi thay đổi ASP.NET Core, EF Core, SQL Server hoặc API, đọc `skills/build-aspnet-sqlserver-api/SKILL.md`.
- Khi khảo sát hoặc triển khai phân hệ từ database/web công ty hiện có, đọc `skills/develop-company-module-from-existing-db/SKILL.md`.
- Chỉ đọc `skills/build-aspnet-sqlserver-api/references/employee-crud-contract.md` khi người dùng yêu cầu module nhân viên greenfield và chưa sử dụng bảng `NHANVIEN` gốc.
- Không dùng contract CRUD nhân viên mẫu để ghi đè schema hoặc nghiệp vụ thật của công ty.

## 13. Kiểm Tra

- Bắt đầu bằng test trực tiếp của feature đã sửa.
- Chạy format: `dotnet format TTSmart.sln --verify-no-changes --no-restore`.
- Chạy test: `dotnet test TTSmart.sln -c Release --no-restore`.
- Chạy build: `dotnet build TTSmart.sln -c Release --no-restore`.
- Với truy vấn phụ thuộc SQL Server, kiểm tra trên `TTSmartMobile_Dev`; test InMemory không thay thế được kiểm tra translation, collation, trigger, stored procedure hoặc hành vi dữ liệu của schema web.
- Với thay đổi auth, kiểm tra login, `/api/auth/me`, `401`, `403`, `Status`, role assignment và quyền function theo `UserRole`/`FunctionRole` sau khi mapping đã được xác minh.
- Kiểm tra cấu hình Development không trỏ vào `dangnhap.net`; không chạy test ghi dữ liệu lên database chuẩn này.
- Không dùng tài khoản hoặc dữ liệu production trong test fixture.

## 14. Bàn Giao

- Nêu phân hệ và use case đã hoàn thành.
- Liệt kê bảng, view, procedure, trigger hoặc function đã khảo sát và sử dụng.
- Phân biệt nghiệp vụ đã xác nhận với giả định còn lại.
- Nêu API contract hoặc breaking change cần người phụ trách mobile cập nhật.
- Báo cáo rõ thao tác database đã thực hiện, dữ liệu test đã dọn, kết quả format/test/build/E2E và phần chưa thể xác minh.
- Nếu có đối chiếu `dangnhap.net`, nêu rõ truy vấn chỉ đọc đã dùng; nếu có thao tác trên `TTSmartMobile_Dev`, nêu rõ dữ liệu/schema bị ảnh hưởng và cách rollback hoặc reset.
- Đề xuất bước nhỏ tiếp theo theo đúng thứ tự nghiệp vụ, không tự mở rộng phạm vi.

## 15. Tổ Chức File, Đặt Tên Và Ranh Giới Module

- Tổ chức code theo phân hệ nghiệp vụ và trách nhiệm kỹ thuật; không tổ chức theo tên người làm, tên task, ngày thực hiện hoặc trạng thái tạm thời.
- Mỗi file phải có một trách nhiệm chính. Đặt code gần phân hệ sở hữu nó nhất; chỉ đưa thành phần vào `Common/` khi có ít nhất hai nơi sử dụng thực tế và không chứa quy tắc riêng của một phân hệ.
- Trước khi tạo file hoặc abstraction mới, phải tìm file, DTO, model, validator, service, repository hoặc mapping tương đương để tránh tạo source of truth thứ hai.
- Không tạo các bản sao có hậu tố `old`, `new`, `final`, `copy`, `backup` hoặc `temp`; lịch sử thay đổi thuộc về Git.
- Thư mục, namespace, class, record, enum và file C# dùng `PascalCase`; interface bắt đầu bằng `I`.
- Controller kết thúc bằng `Controller`, service bằng `Service`, option cấu hình bằng `Options`, exception bằng `Exception`; test class và file dùng hậu tố `Tests`.
- DTO nhận dữ liệu dùng hậu tố `Request`, DTO trả dữ liệu dùng hậu tố `Response`; chỉ dùng hậu tố `Dto` khi không thể đặt tên theo nghiệp vụ cụ thể hơn.
- Validator, mapper, policy, requirement và handler phải có tên thể hiện đúng vai trò; file phải khớp với public type chính bên trong.
- `AccessManagementContracts.cs` chỉ tiếp tục gom các contract liên quan chặt chẽ. Khi User, Role hoặc Function có vòng đời và thay đổi độc lập, tách file theo resource hoặc use case trước khi file trung tâm trở thành điểm conflict.
- Khi tạo, di chuyển hoặc đổi tên file, phải cập nhật namespace, dependency injection, route, test, script, tài liệu và mọi reference liên quan; không đổi tên hàng loạt ngoài phạm vi task.
- Không tạo thư mục, layer, file rỗng, `README.md` hoặc abstraction chỉ để chuẩn bị cho nhu cầu chưa được xác nhận.
- Khi thêm module mới, phải có entry point rõ, feature service, data source/mapping, contract và test tương ứng; phần bàn giao phải chỉ ra đường đọc code từ controller đến database và test.

## 16. Kiến Trúc Bảo Mật Backend

- Mobile, UI, route, field ẩn/disabled, bộ lọc và mọi input từ client đều không đáng tin; backend là ranh giới bảo mật cuối cùng.
- Không dùng việc ẩn menu hoặc nút trên Flutter làm cơ chế bảo mật. Mỗi endpoint phải kiểm tra authentication, permission, validation, data scope và business rule ở backend.
- Áp dụng quyền tối thiểu cho API, database connection, role và dữ liệu; khi danh tính, quyền hoặc phạm vi dữ liệu không thể xác minh thì từ chối an toàn.
- Không coi dữ liệu nội bộ, mạng công ty, VPN hoặc thiết bị công ty là lý do để bỏ qua kiểm tra bảo mật.
- Không mở quyền, tắt authorization hoặc bỏ validation tạm thời chỉ để demo, chạy E2E hoặc làm giao diện hoạt động.
- Thay đổi liên quan authentication, authorization, password, scope hoặc dữ liệu nhạy cảm phải đánh giá đồng thời API contract, mobile, database, logging và test.

## 17. Authentication Và Vòng Đời Phiên

- Access token phải có thời hạn được cấu hình phù hợp với rủi ro; không tạo token sống quá dài nếu không có cơ chế vô hiệu hóa tương ứng.
- Backend phải kiểm tra chữ ký, issuer, audience, thời hạn, trạng thái tài khoản và quyền hiện tại theo contract; thay đổi quyền hoặc khóa User phải có hiệu lực đúng yêu cầu, không phụ thuộc vô thời hạn vào claim cũ.
- Dùng `401 Unauthorized` cho request chưa xác thực hoặc phiên không hợp lệ và `403 Forbidden` cho User đã xác thực nhưng thiếu quyền.
- Không truyền hoặc lưu token qua URL, query string, log, analytics, clipboard, screenshot hoặc thông báo lỗi; không log `Authorization` header.
- Mobile phải lưu token bằng secure storage; backend không hardcode tài khoản, mật khẩu, token, OTP hoặc phiên Development trong source, fixture, screenshot hay tài liệu.
- Chỉ triển khai refresh token khi có yêu cầu và contract được xác nhận; nếu triển khai phải có đánh giá rotation, revoke, reuse detection và vô hiệu hóa phiên.
- Mobile gửi mật khẩu gốc qua HTTPS theo contract hiện tại; backend tiếp tục xử lý công thức hash legacy của website và không trả `Password`, `KeyLock` hoặc hash trong response.
- Logout mobile dùng POST /api/auth/logout và cột User.TokenSince làm mốc thu hồi phiên toàn tài khoản; không thêm bảng hoặc cột phiên mới khi chưa có yêu cầu đăng xuất riêng từng thiết bị.
- JWT mobile phải có claim iat hợp lệ. Mỗi request so sánh thời điểm phát hành token với User.TokenSince; token phát hành trước hoặc bằng mốc thu hồi phải trả 401 với code session_revoked.
- Login không tự cập nhật TokenSince. Khi đăng nhập lại ngay sau logout, backend phải phát hành JWT có iat lớn hơn TokenSince để token mới dùng được mà không làm JWT cũ sống lại.
- Logout, đổi mật khẩu và reset mật khẩu phải cập nhật TokenSince để JWT cũ mất hiệu lực ở request kế tiếp. Flutter vẫn phải xóa access token khỏi secure storage sau logout hoặc khi nhận session_revoked.

## 18. Secret Và Cấu Hình Môi Trường

- Tách Development, Staging và Production; không dùng chung secret hoặc connection string nhạy cảm giữa các môi trường.
- `appsettings.json` và `appsettings.*.json` chỉ chứa cấu hình không nhạy cảm hoặc placeholder. Local secret dùng User Secrets, biến môi trường hoặc cơ chế ngoài repository; `Properties/launchSettings.json` chỉ dành cho cấu hình chạy local, không phải kho lưu secret production.
- Production phải lấy JWT signing key, database credential và secret khác từ secret manager hoặc cơ chế secret của hạ tầng triển khai; không hardcode trong C#, controller, script, tài liệu hoặc mobile.
- Khi đổi database, ưu tiên thay `ConnectionStrings__AuthConnection` hoặc khóa cấu hình tương đương ngoài code; không hardcode `dangnhap.net` hay tên database trong service/controller.
- Development phải có guardrail để phát hiện kết nối nhầm `dangnhap.net`; mọi thao tác ghi và test E2E phải hướng vào `TTSmartMobile_Dev`.
- Không commit secret thật, password, private key, certificate private key, backup nhạy cảm hoặc file môi trường có credential. Nếu nghi ngờ secret đã lộ, phải rotate/revoke và đánh giá lịch sử Git, log và artifact.
- Không đưa URL nội bộ, tên server, credential, dữ liệu production hoặc thông tin hạ tầng nhạy cảm vào `AGENTS.md`, fixture, screenshot, log hoặc tài liệu API.

## 19. Logging, Audit Và Giám Sát

- Ưu tiên structured logging và dùng `traceId` hoặc `correlationId` để đối chiếu một request xuyên backend-mobile.
- Tuyệt đối không log mật khẩu, password hash, access token, refresh token, OTP, secret, connection string, private key, authorization header hoặc payload xác thực nhạy cảm.
- Dữ liệu cá nhân và dữ liệu công ty nhạy cảm trong log phải được loại bỏ, che một phần, rút gọn hoặc thay bằng định danh nội bộ an toàn; không log toàn bộ request/response khi payload nhạy cảm.
- Production API chỉ trả `ProblemDetails` an toàn; không trả stack trace, SQL exception, inner exception, tên bảng, đường dẫn server, hostname hoặc chi tiết hạ tầng.
- Các thao tác login thất bại/thành công phù hợp, khóa tài khoản, thay đổi role, thay đổi function permission và CRUD quản trị quan trọng phải được đánh giá nhu cầu audit riêng; audit phải xác định actor, hành động, thời điểm, đối tượng, kết quả và trace ID mà không ghi secret.
- Log chạy thử, log điều tra và artifact tạm không phải source of truth, không đưa vào `docs/` chính thức và không commit.

## 20. Dependency Và Supply Chain

- Không thêm package, SDK hoặc binary chỉ vì ví dụ bên ngoài đề xuất. Trước khi thêm dependency phải đánh giá nhu cầu thật, khả năng dùng thành phần hiện có, tình trạng duy trì, phiên bản, giấy phép, quyền nhạy cảm, rủi ro bảo mật và ảnh hưởng build/deploy.
- Ưu tiên dependency hiện có; không dùng nhiều package cho cùng một trách nhiệm, không thêm package chỉ để giảm ít code và không tự thay DI, serializer, HTTP client hoặc framework nền.
- Mọi thay đổi dependency phải nằm trong phạm vi task, cập nhật lockfile hoặc file project tương ứng và được kiểm tra build/test; không nâng version hàng loạt.
- Không bỏ qua cảnh báo bảo mật dependency chỉ để pipeline xanh. Nếu có lỗ hổng nghiêm trọng, phải ghi rõ package, phiên bản, phạm vi ảnh hưởng, phương án cập nhật/giảm thiểu và rủi ro breaking change.
- Không dùng package không rõ nguồn, binary không thể xác minh hoặc credential trong cấu hình package manager.

## 21. Bảo Mật Mạng Và Dữ Liệu Đầu Vào

- Production chỉ giao tiếp qua HTTPS; không vô hiệu hóa kiểm tra chứng chỉ, bỏ qua TLS hoặc chấp nhận mọi certificate trong build production.
- Backend phải kiểm tra kiểu, định dạng, độ dài, khoảng giá trị, trạng thái, quan hệ, permission và data scope của mọi request từ mobile hoặc hệ thống ngoài.
- Không tin `userId`, `stationId`, `companyId`, role, function, quyền, trạng thái hoặc field readonly do client gửi lên; backend phải tự lấy từ danh tính hiện tại hoặc xác minh lại.
- Không nối chuỗi SQL từ input và không dùng raw SQL không tham số hóa. Với upload trong tương lai, phải kiểm tra kích thước, extension, MIME, nội dung, tên file, số lượng và vị trí lưu an toàn.
- Chỉ thu thập, truyền và lưu dữ liệu cần cho use case. Dữ liệu nhạy cảm cache hoặc lưu local phải có mục đích, thời hạn, invalidation và cơ chế xóa rõ ràng.

## 22. Kiểm Thử Bảo Mật Và Chất Lượng

- Với feature có authorization, tối thiểu phải kiểm tra token thiếu/hết hạn/sai, token hợp lệ nhưng thiếu quyền (`403`), User bị khóa, thay đổi quyền và dữ liệu ngoài scope.
- Kiểm tra client tự sửa định danh, role, function, quyền, trạng thái hoặc scope không thể vượt qua backend; validation phải nhất quán và không lộ chi tiết nội bộ.
- Với thao tác ghi, kiểm tra transaction, rollback, duplicate, conflict, concurrency và side effect của trigger/database object khi có liên quan.
- SQL E2E trên `TTSmartMobile_Dev` là bắt buộc khi hành vi phụ thuộc SQL Server; test InMemory không thay thế kiểm tra translation, collation, trigger, procedure hoặc dữ liệu clone.
- Không tắt test, bỏ assertion hoặc nới điều kiện bảo mật để pipeline xanh. Nếu không chạy được integration/E2E/security test, phải nêu rõ trong bàn giao.

## 23. Hiệu Năng Và Khả Năng Vận Hành

- API danh sách lớn phải cân nhắc phân trang, filter, search, sort ổn định và giới hạn page size; không tải toàn bộ bảng hoặc graph chỉ để hiển thị một phần.
- Dùng projection và `AsNoTracking` cho truy vấn chỉ đọc, tránh N+1 và truy vấn lặp không kiểm soát; không tối ưu sớm nhưng phải tránh lỗi hiệu năng rõ ràng.
- Truyền `CancellationToken`, cấu hình timeout hợp lý và giới hạn retry; không retry vô hạn hoặc lặp thao tác ghi không idempotent gây trùng dữ liệu.
- Không cache dữ liệu nhạy cảm, quyền hoặc trạng thái tài khoản nếu chưa có expiration và invalidation phù hợp.
- Chỉ thêm cache, background task, queue, batch hoặc scheduled job khi có use case được xác nhận; phải xác định owner, retry, idempotency, khả năng quan sát, cách dừng và rollback.

## 24. Bảo Trì Và Tương Thích API

- Ưu tiên thay đổi nhỏ, độc lập, dễ review và dễ rollback; không refactor toàn bộ module khi task chỉ yêu cầu một use case.
- Không tạo source of truth thứ hai cho cùng một logic. Breaking change phải ghi rõ consumer bị ảnh hưởng, lý do, migration path, versioning khi cần, kế hoạch rollout/rollback và cập nhật đồng bộ OpenAPI, `docs/`, test và thông tin cho mobile.
- Không xóa hoặc đổi field API đang được mobile sử dụng nếu chưa đánh giá tương thích ngược; ưu tiên bổ sung field hoặc chuyển tiếp tương thích khi có thể.
- Không để TODO kiến trúc, placeholder, mock vĩnh viễn hoặc hardcode che lỗi tồn tại như giải pháp lâu dài.
- Mỗi feature phải có đường đọc code rõ từ controller/endpoint đến contract, service, data access, authorization và test; quyết định bền vững phải nằm trong code, test, contract, tài liệu hoặc `AGENTS.md`, không chỉ trong hội thoại.

## 25. Phối Hợp Agent Và Bàn Giao Backend

- Trước khi sửa, phải xác định rõ phân hệ, thư mục/file được phép sửa, contract, database object, dependency và lệnh kiểm tra liên quan.
- API contract, composition root, cấu hình dùng chung, database script quan trọng và lockfile chỉ có một owner điều phối tại một thời điểm; không để hai agent cùng sửa một file hoặc contract khi chưa có cơ chế tích hợp rõ.
- Backend là source of truth của route, request, response, validation, authorization, status code và error contract sau khi đã xác minh. Agent backend không tự sửa mobile để che lỗi contract, trừ khi task xuyên dự án giao rõ cả hai phạm vi.
- Khi API thay đổi, phải thông báo phần mobile cần cập nhật DTO, repository, state/controller, UI và test; không âm thầm tạo breaking change.
- Không ghi đè, reset, checkout đè hoặc hoàn tác thay đổi hợp lệ của agent khác; không dùng lệnh Git phá hủy thay đổi khi chưa được yêu cầu rõ.
- Nếu dùng subagent, chỉ giao việc độc lập với phạm vi file, nguồn sự thật, tiêu chí hoàn thành và lệnh kiểm tra rõ; subagent không được tự thêm dependency, đổi contract, sửa database hoặc mở rộng phạm vi.
- Trước bàn giao phải kiểm tra diff, file ngoài phạm vi, file tạm, log, conflict, lockfile và cấu hình; báo rõ file đã sửa, bảng/object sử dụng, lệnh/kết quả kiểm tra, giả định, phần chưa xác minh và rủi ro tích hợp.
