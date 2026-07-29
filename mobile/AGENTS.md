# Hướng Dẫn Agent Mobile

## 1. Quan Hệ Với Hướng Dẫn Tổng

- Kế thừa toàn bộ quy tắc trong `D:\TTSmartApp\AGENTS.md`.
- File này bổ sung quy tắc riêng cho `D:\TTSmartApp\mobile` và được ưu tiên cho chi tiết triển khai Flutter.
- Không được áp dụng quy tắc mobile theo cách làm sai mục tiêu, ranh giới kiến trúc hoặc thứ tự nguồn thông tin của file tổng.
- Trước khi sửa code, kiểm tra hướng dẫn này còn phù hợp với source, package, kiến trúc và lệnh kiểm tra hiện tại hay không.
- File này phải phản ánh đúng cấu trúc Flutter, state management, API client, điều hướng, UI và lệnh kiểm tra đang dùng trong repository.
- Khi xuất hiện thay đổi bền vững về kiến trúc, quy trình, dependency, contract hoặc lệnh kiểm tra, cập nhật file này trong cùng phạm vi công việc; không ghi trạng thái tạm thời của một task hoặc chi tiết quá nhỏ của một màn hình.

## 2. Vai Trò Và Phạm Vi

- Phụ trách toàn bộ phần mobile Flutter của ứng dụng dùng cho TTSmart và các công ty khách hàng sử dụng sản phẩm TTSmart.
- Phạm vi ưu tiên hiện tại là ứng dụng quản lý tập trung nhiều trạm trộn cho cấp công ty, gồm dữ liệu tổng hợp và chi tiết từng trạm.
- Tách rõ tenant/công ty sở hữu tài khoản, quyền chức năng và phạm vi dữ liệu; cùng một giao diện có thể hiển thị module, hành động và dữ liệu khác nhau theo phiên do backend cấp.
- Chế độ để một trạm tự quản lý hoặc theo dõi riêng là định hướng tương lai; không xây trước luồng, cấu hình hay UI riêng nếu người dùng chưa yêu cầu.
- Ứng dụng có thể kế thừa một phần, khác hoặc thay thế luồng website hiện tại theo nghiệp vụ người dùng xác nhận; website chỉ là nguồn tham khảo và đối chiếu.
- Triển khai lần lượt từng phân hệ nhỏ và hoàn thiện trọn luồng mobile của phân hệ đó trước khi mở rộng sang phân hệ tiếp theo.
- Backend C# ASP.NET Core Web API do agent hoặc đội backend phụ trách riêng.
- Database `dangnhap.net` là nguồn tham chiếu kỹ thuật và dữ liệu chuẩn của website hiện tại; mobile không kết nối hoặc thao tác trực tiếp trên database này.
- Database `TTSmartMobile_Dev` là database làm việc cho phát triển và kiểm thử backend; mobile chỉ sử dụng API của môi trường Development và không tự thực hiện migration, seed, reset, backup hoặc restore database.
- Tuyệt đối không để công cụ, script hoặc cấu hình mobile ghi vào `dangnhap.net`; mọi nhu cầu dữ liệu phát triển phải được backend cung cấp từ `TTSmartMobile_Dev`.
- Không tạo hoặc chỉnh sửa controller, service, Entity Framework mapping, migration, SQL, stored procedure, function, trigger hoặc hạ tầng backend, trừ khi người dùng thay đổi phạm vi rõ ràng.
- Được phép đọc backend, OpenAPI, DTO, test và tài liệu liên quan để xác nhận API contract; không được âm thầm sửa backend để làm cho mobile chạy.

## 3. Kiến Trúc Hệ Thống

- Frontend mobile: Flutter và Dart trong repository này.
- Backend: C# với ASP.NET Core Web API.
- Database: Microsoft SQL Server, chỉ backend được kết nối trực tiếp.
- Luồng chuẩn: `Flutter -> HTTPS/JSON REST API -> ASP.NET Core -> EF Core hoặc data access backend -> SQL Server`.
- Không lưu connection string, tài khoản database, tên server nội bộ hoặc chi tiết schema cần bảo mật trong ứng dụng.
- Không để UI phụ thuộc vào entity EF Core, tên bảng, view, stored procedure hoặc cách backend mapping database.

## 4. Nguồn Thông Tin Khi Làm Phân Hệ

Áp dụng thứ tự ưu tiên trong `D:\TTSmartApp\AGENTS.md` và diễn giải cho mobile như sau:

1. Yêu cầu và xác nhận trực tiếp của người dùng.
2. Schema, constraint, quan hệ và dữ liệu hợp lệ trong `dangnhap.net` do backend khảo sát read-only và cung cấp để xác định mô hình kỹ thuật; mọi thao tác phát triển và kiểm thử có ghi dữ liệu phải dùng `TTSmartMobile_Dev`.
3. API contract, OpenAPI, DTO, JSON thực tế, backend test và mã nguồn backend liên quan.
4. Hành vi website công ty đã được quan sát hoặc tài liệu nghiệp vụ đã được cung cấp, chỉ dùng để tham khảo và đối chiếu.
5. Giả định tạm thời, phải được ghi rõ và giữ ở ranh giới dễ thay đổi.

- Không suy diễn nghiệp vụ chỉ từ tên bảng, tên cột, tên field hoặc giao diện website.
- Không tuyên bố màn hình đã giống website nếu chưa đối chiếu được hành vi thực tế.
- Khi website, database và API có điểm khác nhau, ghi rõ mâu thuẫn và xác nhận hướng xử lý trước khi cố định UI hoặc model.
- View, stored procedure, function, trigger hoặc quy tắc dữ liệu cũ là bằng chứng để phân tích, không tự động là yêu cầu bắt buộc của app mới.
- Không chỉnh sửa trực tiếp file `.mdf`, `.ldf`, bản backup hoặc database artifact; mọi thay đổi dữ liệu và schema thuộc phạm vi backend/database.

## 5. Công Nghệ Và Quy Ước Hiện Tại

- Sử dụng Flutter và Dart cho toàn bộ mobile.
- Ưu tiên package, state management, routing và coding style đang có trong source trước khi thêm giải pháp mới.
- Source hiện tại dùng `http` cho REST API và `ChangeNotifier` cho state cục bộ; không tự chuyển sang `dio`, Riverpod, BLoC hoặc package khác nếu chưa có nhu cầu rõ ràng.
- Không thêm code generation, dependency injection framework, navigation framework hoặc kiến trúc nhiều tầng chỉ để chuẩn bị cho tương lai.
- Chỉ thêm dependency khi giải quyết nhu cầu cụ thể, tương thích nền tảng và có thể kiểm thử.
- Dependency wiring hiện dùng thủ công qua `lib/main.dart`, `lib/app.dart`, `AppFeatureRepositories` và các composition root liên quan; không chuyển sang DI framework nếu chưa có vấn đề thực tế cần giải quyết.
- Auth và RBAC dùng backend thật. Repository mock/in-memory chỉ được dùng khi người dùng xác nhận làm FE trước cho phân hệ chưa có API; controller và UI phải phụ thuộc abstraction, contract backend dự kiến phải được ghi lại và mock không được trở thành source of truth production.
- Tổ chức code theo feature; phần dùng chung đặt trong `lib/core/`, từng phân hệ đặt trong `lib/features/<feature_name>/`.
- Dùng `lib/main.dart` làm composition root mỏng: khởi tạo Flutter, đọc cấu hình, tạo API client/repository/controller và gọi `runApp`; không đặt UI hoặc nghiệp vụ phân hệ trong file này.
- Dùng `lib/app.dart` làm app root: theme, `MaterialApp`, trạng thái phiên và App Shell; không đưa logic gọi API của từng phân hệ vào đây.
- Không áp dụng máy móc cấu trúc toàn cục `lib/data/`, `lib/domain/`, `lib/ui/` của skill kiến trúc; TTSmart dùng feature-first để giữ ranh giới từng phân hệ rõ ràng.
- Không dùng tên, model, route hoặc contract của module thử nghiệm cũ làm đặc tả mặc định; mỗi phân hệ TTSmart phải được đặt tên theo nghiệp vụ và API backend đã xác nhận.

## 6. Kiến Trúc Mobile Theo Phân Hệ

Mỗi phân hệ nên có ranh giới tương đương:

```text
lib/
  main.dart
  app.dart
  core/
    config/
    network/
    storage/
    theme/
    utils/
    widgets/
  features/<feature_name>/
    data/
      models/
      repositories/
      datasources/       # chỉ khi cần tách API hoặc nguồn lưu trữ
    domain/              # tùy chọn, chỉ khi nghiệp vụ đủ phức tạp
      models/
      use_cases/
    presentation/
      controllers/
      screens/
      widgets/
test/
  core/
  features/<feature_name>/
```

Trong phạm vi một phân hệ:

```text
lib/features/<feature_name>/
  data/
    models/
    repositories/
    storage/ hoặc datasources/ khi cần
  presentation/
    controllers/
    screens/
    widgets/
```

- Được phép gộp bớt tầng nếu tầng đó chỉ chuyển tiếp dữ liệu và không tạo ranh giới hữu ích.
- `data/models/` chứa DTO hoặc model bám theo API; không để model phụ thuộc entity EF Core, tên bảng hoặc schema SQL Server.
- Chỉ tạo `domain/` và `use_cases/` khi có biến đổi nghiệp vụ phức tạp, logic dùng lại giữa nhiều controller hoặc phối hợp nhiều repository; CRUD đơn giản không cần tạo tầng này cho đủ hình thức.
- Repository là ranh giới truy cập dữ liệu và chuyển đổi response; controller không tự xây URL, header, JSON hoặc gọi `http` trực tiếp.
- Widget chỉ hiển thị và xử lý tương tác; không gọi HTTP hoặc parse JSON trực tiếp.
- Đặt HTTP call sau API client hoặc data source và truy cập qua repository.
- Tách DTO API khỏi state hoặc model UI khi hai cấu trúc có mục đích khác nhau.
- Mỗi controller và model file nên tập trung vào một nhóm trách nhiệm; khi một file chứa nhiều luồng độc lập như users, roles và functions, phải tách thành các file riêng trước khi tiếp tục mở rộng.
- Screen giữ vai trò điều phối UI; tách form section, list item, dialog hoặc card thành `presentation/widgets/` khi có logic riêng, được tái sử dụng hoặc làm screen khó đọc/khó kiểm thử.
- Không tạo thư mục `widgets/`, `domain/` hoặc `datasources/` rỗng chỉ để khớp mẫu; chỉ thêm khi có ranh giới hoặc hành vi thực tế cần quản lý.
- Đặt base URL, timeout, header, xác thực, serialization và chuyển đổi lỗi dùng chung trong `lib/core/`.
- `lib/core/` chỉ chứa thành phần dùng chung thật sự cho từ hai phân hệ trở lên hoặc là hạ tầng app; logic chỉ dùng một phân hệ phải nằm trong feature đó.
- Dependency wiring hiện dùng thủ công tại composition root; không thêm `get_it`, code generation hoặc DI framework nếu chưa có nhu cầu cụ thể.
- Registry menu và mapping function-to-route thuộc `features/shell/`; feature không được tự sửa quyền hoặc mở trực tiếp route của feature khác.
- Thư mục `test/` phải phản chiếu ranh giới `lib/`, ưu tiên test model, API client, repository và controller; không đưa test phụ thuộc AVD vào unit/widget test khi không cần.
- Không tạo abstraction dùng chung chỉ dựa trên một trường hợp của một phân hệ.

## 7. App Shell, Menu Và Phân Quyền

- Sau đăng nhập, ứng dụng đi vào App Shell; không mở cứng một phân hệ nghiệp vụ làm màn hình gốc lâu dài.
- App Shell hiện dùng bốn tab cố định `Trang chủ`, `Đơn hàng`, `Báo cáo`, `Xem thêm` và `IndexedStack` để giữ state, vị trí cuộn, search và filter khi đổi tab.
- Header chung chứa avatar tài khoản, vùng logo tenant có kích thước ổn định, thông báo và cài đặt; avatar chỉ mở hồ sơ, không thay cho menu nghiệp vụ.
- Function backend và registry tập trung trong `features/shell/` chỉ quyết định module hoặc route đã có function code được xác nhận; không tự phát minh function code backend cho module mới.
- Không hardcode quyền theo tên role.
- Với module Hệ thống, chỉ hiển thị route có mapping và quyền `dSach` trên function code `QLND`, `QLQ` hoặc `QLCN`.
- Module FE bản xem trước chưa có API hoặc function code chỉ được mở màn giới thiệu/empty state không chứa dữ liệu nhạy cảm hay thao tác đặc quyền; trước production phải thay bằng mapping quyền thật.
- Backend sử dụng `ActiveKey` đúng 9 ký tự theo thứ tự `view`, `create`, `update`, `delete`, `import`, `export`, `print`, `other`, `dSach`.
- `full` là trạng thái tổng hợp của 9 quyền, không phải vị trí thứ 10; logic parse/tạo `ActiveKey` phải tập trung trong model hoặc mapper.
- Luồng gán quyền phải cập nhật ma trận role-function bằng `functionId` số nguyên và `activeKey`, không gửi `right` hoặc `possibleRight`.
- Function cha vẫn được giữ trong cây khi `activeKey` là `000000000` nếu có function con được cấp quyền.
- Function chưa có route mobile không được mở bằng route trực tiếp; báo rõ cần bổ sung mapping khi bàn giao.
- Ẩn menu chỉ phục vụ trải nghiệm; backend vẫn quyết định authorization cuối cùng cho mọi API.
- Route được bảo vệ phải kiểm tra lại quyền từ phiên hiện tại, không chỉ dựa vào việc menu có hiển thị hay không.
- Module dữ liệu vận hành phải thể hiện rõ đang xem toàn công ty hay trạm nào và chỉ cho phép chuyển phạm vi theo quyền backend cấp.

## 8. Xác Thực Và Phiên Đăng Nhập

- Lưu access token hoặc refresh token nhạy cảm bằng secure storage, không dùng plain-text preferences.
- Khi mở app, đọc token, kiểm tra hết hạn nếu có thông tin và xác minh phiên qua endpoint backend công bố.
- `401 Unauthorized`: xóa token, xóa state phiên, đóng các route được bảo vệ và quay về Login.
- `403 Forbidden`: không đăng xuất; hiển thị thông báo hoặc màn hình không có quyền.
- Chỉ triển khai refresh token khi backend có endpoint và contract tương ứng.
- Không hardcode tài khoản Development, mật khẩu seed hoặc token trong source, fixture, screenshot hay tài liệu mobile.
- Không log token, mật khẩu, authorization header hoặc payload chứa dữ liệu nhạy cảm.

## 9. Hợp Đồng API Với Backend

- Xem OpenAPI hoặc Swagger đã cập nhật là nguồn contract chính của mobile khi khớp với response thực tế.
- Mặc định JSON dùng tên thuộc tính `camelCase`; chỉ dùng quy tắc khác khi contract xác nhận.
- Xác nhận rõ endpoint, method, header, request, response, status code, nullable, enum, phân trang, tìm kiếm và response envelope.
- Giữ nguyên kiểu định danh do server cấp, gồm số nguyên, chuỗi hoặc `Guid`; không chuyển kiểu làm mất dữ liệu.
- Parse timestamp theo ISO 8601 và UTC; chỉ đổi sang giờ địa phương tại lớp hiển thị.
- Parse trường chỉ có ngày theo `yyyy-MM-dd`, không tự áp múi giờ.
- Xử lý `decimal`, boolean, nullable và enum theo JSON thực tế, không suy luận từ kiểu cột SQL Server.
- Ưu tiên ASP.NET Core `ProblemDetails`; ánh xạ validation error về đúng field khi response cung cấp.
- Khi backend thay đổi contract, cập nhật đồng bộ DTO, parsing, API client, repository, state, UI và test mobile liên quan.
- Nếu mobile cần thay đổi contract, mô tả rõ endpoint, method, request, response, status code, lý do và tương thích ngược để đội backend xử lý.
- API dữ liệu vận hành phải xác định rõ phạm vi trạm lấy từ phiên đăng nhập, cấu hình server hay tham số đã được backend authorization kiểm tra.
- Mobile không tự tin tưởng `stationId`, `companyId` hoặc mã phạm vi do người dùng nhập hoặc thay đổi nếu backend chưa xác nhận quyền với phạm vi đó.
- Bộ lọc công ty hoặc trạm trên UI chỉ phục vụ truy vấn và trải nghiệm; không được xem là cơ chế authorization hoặc bảo vệ dữ liệu.

## 10. Chuyển Nghiệp Vụ Web Sang Mobile

- Website là nguồn tham khảo về use case, dữ liệu, thứ tự thao tác và quy tắc nghiệp vụ; không sao chép nguyên bố cục desktop sang điện thoại.
- Xác định hành động chính, thông tin ưu tiên và tần suất sử dụng trước khi thiết kế màn hình.
- Chuyển bảng rộng thành danh sách, card, màn chi tiết, bộ lọc hoặc bottom sheet phù hợp mobile.
- Tách quy trình dài thành các bước rõ ràng khi cần, nhưng không tự thay đổi nghiệp vụ đã xác nhận.
- Giữ thuật ngữ nghiệp vụ nhất quán với công ty và website khi thuật ngữ đó đã được xác nhận.
- Khi phải đơn giản hóa luồng web cho mobile, nêu rõ điểm khác và lý do.

## 11. Trạng Thái, Lỗi Và Trải Nghiệm

- Mỗi màn hình dữ liệu phải xử lý loading, empty, success, validation error, network error, unauthorized, forbidden và retry khi phù hợp.
- Không để widget rebuild tạo request lặp hoặc gửi form nhiều lần.
- Giữ dữ liệu người dùng đã nhập khi lỗi còn có thể khắc phục.
- Xác nhận trước thao tác phá hủy hoặc khó hoàn tác.
- Hiển thị thông báo tiếng Việt ngắn gọn, nêu được vấn đề và hành động tiếp theo.
- Không hiển thị payload thô, stack trace, SQL error hoặc chi tiết hạ tầng backend trên UI production.
- Validation Flutter phục vụ trải nghiệm; backend vẫn là nơi quyết định validation nghiệp vụ và authorization.

## 12. UI Và Khả Năng Tiếp Cận

- Xây dựng giao diện đúng đặc trưng mobile, không thu nhỏ giao diện web.
- Tôn trọng `SafeArea`, bàn phím, focus, cuộn, nút quay lại và điều hướng hệ điều hành.
- Dùng typography dễ đọc, màu tiết chế, viền nhẹ, bo góc vừa phải và hạn chế đổ bóng.
- Vùng chạm nên đạt khoảng 48 logical pixel khi phù hợp.
- Không truyền đạt trạng thái chỉ bằng màu sắc; kết hợp icon, nhãn hoặc mô tả.
- Form phải cuộn được, lỗi hiển thị gần field và hành động chính có trạng thái loading hoặc disabled rõ ràng.
- Chỉ tham khảo phần phù hợp từ skill web; không áp dụng CSS, hover, desktop grid hoặc animation trang trí không phù hợp mobile.

## 13. Quy Trình Triển Khai Một Phân Hệ

1. Đọc `D:\TTSmartApp\AGENTS.md`, file này và skill liên quan.
2. Xác định tên phân hệ, use case cấp công ty, phạm vi toàn công ty hoặc từng trạm, function quyền và phiên bản đầu.
3. Đối chiếu website hoặc tài liệu nghiệp vụ nếu có.
4. Đọc OpenAPI, DTO, JSON mẫu, backend test và endpoint liên quan.
5. Ghi rõ contract đã xác nhận, điểm chưa rõ và phụ thuộc backend.
6. Thiết kế route, menu, state, model, repository và các màn hình mobile cần thiết.
7. Triển khai một vertical slice chạy được trước khi mở rộng thêm use case.
8. Kiểm tra quyền, lỗi, nullable, enum, ngày giờ, phân trang và tương thích ngược.
9. Cập nhật test, tài liệu và `AGENTS.md` nếu xuất hiện quy tắc bền vững mới.

## 14. Skill Bắt Buộc

- Trước khi triển khai hoặc sửa một phần hệ thống, phải xác định skill liên quan và đọc file `SKILL.md` tương ứng; không cần đọc toàn bộ skill nếu task không sử dụng phần đó.
- Skill trong `.agents/skills/` là bộ skill kỹ thuật được Codex tự động nhận diện của project; skill trong `skills/` là skill nghiệp vụ riêng của mobile và phải đọc khi đúng phạm vi.
- Đọc `skills/flutter-business-module/SKILL.md` khi khảo sát hoặc triển khai một phân hệ nghiệp vụ mới, App Shell, menu động, route theo function hoặc chuyển luồng từ website sang mobile.
- Đọc `skills/flutter-mobile-crud/SKILL.md` khi phân hệ có danh sách, chi tiết, thêm, sửa, xóa, tìm kiếm, lọc, phân trang hoặc form validation.
- Có thể dùng cả hai skill cho cùng một phân hệ; skill nghiệp vụ xác định ranh giới và luồng, skill CRUD hướng dẫn hành vi màn hình dữ liệu.
- Đọc `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md` khi tạo cấu trúc mới, tổ chức layer hoặc refactor kiến trúc Flutter.
- Đọc `.agents/skills/flutter-use-http-package/SKILL.md` khi triển khai hoặc sửa API client, HTTP request, timeout, header hoặc xử lý response.
- Đọc `.agents/skills/flutter-implement-json-serialization/SKILL.md` khi tạo hoặc cập nhật model, DTO, `fromJson` hoặc `toJson`.
- Đọc `.agents/skills/flutter-setup-declarative-routing/SKILL.md` khi thay đổi routing, deep link hoặc điều hướng khai báo; không tự thêm router package nếu source chưa có nhu cầu.
- Đọc `.agents/skills/flutter-build-responsive-layout/SKILL.md` khi xây dựng giao diện thích ứng nhiều kích thước màn hình, điện thoại hoặc tablet.
- Đọc `.agents/skills/ui-ux-pro-max/SKILL.md` khi thiết kế, review hoặc cải thiện UI/UX; chỉ áp dụng phần mobile và Flutter, bỏ qua hướng dẫn dành riêng cho web.
- Đọc `.agents/skills/flutter-add-widget-test/SKILL.md` khi viết widget test; đọc `.agents/skills/dart-add-unit-test/SKILL.md` khi viết unit test cho logic hoặc model.
- Đọc `.agents/skills/dart-run-static-analysis/SKILL.md` khi chạy hoặc xử lý kết quả phân tích tĩnh Dart.
- Chỉ dùng `imagegen-frontend-mobile` khi người dùng cần mockup hoặc asset hình ảnh; không dùng để thay thế UI Flutter thật.
- Chỉ tham khảo `minimalist-ui` về độ nhiễu thị giác, khoảng cách, màu và phân cấp; bỏ qua quy tắc dành riêng cho CSS hoặc web.

## 15. Kiểm Tra Trước Khi Bàn Giao

- Format file Dart đã thay đổi; ưu tiên format phạm vi hẹp trước và chạy `dart format .` khi môi trường phù hợp.
- Chạy `flutter analyze`.
- Chạy unit test và widget test liên quan; sau đó chạy `flutter test` khi phạm vi hoặc thời gian cho phép.
- Build nền tảng bị ảnh hưởng, tối thiểu APK debug cho thay đổi Android khi môi trường hỗ trợ.
- Kiểm tra parsing bằng JSON mẫu thật và payload request theo contract.
- Kiểm tra menu, route guard, `401`, `403`, loading, empty, retry và form submission khi phân hệ có liên quan.
- Với UI ma trận quyền, kiểm tra trường hợp chưa gán function, gán một hoặc nhiều quyền, bật/tắt `Đầy đủ`, `ActiveKey` rỗng 9 ký tự, payload thay thế và phản hồi `400`/`403`/`409`.
- Với dữ liệu theo trạm, kiểm tra hiển thị đúng phạm vi, từ chối truy cập chéo trạm và hành vi khi thiếu hoặc cố thay đổi mã trạm.
- Không chạy smoke test bằng credential hoặc dữ liệu thật khi chưa có môi trường test an toàn; không tự bật AVD nếu không cần cho phạm vi kiểm tra và phải báo rõ phần runtime chưa được xác minh.
- Không bàn giao placeholder, TODO thay logic thật, method chưa hoàn thiện hoặc code lỗi bị comment lại.
- Báo cáo rõ file đã thay đổi, nghiệp vụ đã xác nhận, giả định còn lại, endpoint chưa xác minh, kết quả test và phần phụ thuộc backend.

## 16. Bảo Mật Và Dữ Liệu Công Ty

- Không commit secret, token, mật khẩu, connection string, URL production riêng hoặc tài khoản nội bộ.
- Không sao chép dữ liệu công ty thật vào test fixture nếu không cần thiết; phải ẩn danh khi cần dùng dữ liệu mẫu.
- Không đưa thông tin production vào source, tài liệu, screenshot, mockup hoặc `AGENTS.md`.
- Làm sạch log debug và dữ liệu mẫu trước khi bàn giao.
- Khi phát hiện contract hoặc UI có thể làm lộ dữ liệu nhạy cảm, dừng mở rộng phần đó và nêu rõ rủi ro để xác nhận.

## 17. Tổ Chức File, Đặt Tên Và Tài Liệu

- Áp dụng toàn bộ quy tắc cấu trúc và đặt tên trong mục 17 của `D:\TTSmartApp\AGENTS.md` cho cây `mobile/`.
- File Dart dùng `lower_snake_case.dart`; class, enum, extension dùng `UpperCamelCase`; biến, method và parameter dùng `lowerCamelCase`.
- Screen mới tiếp tục dùng hậu tố `_screen.dart`; test dùng `_test.dart` và phản chiếu feature hoặc hành vi production tương ứng.
- Không tạo file hoặc thư mục theo tên task, người làm, ngày, trạng thái tạm hay hậu tố `old`, `new`, `final`, `copy`, `backup`, `temp`.
- Không tạo `helpers.dart`, `utils.dart`, `common.dart`, `shared.dart` như nơi chứa logic chưa xác định owner; thành phần dùng chung phải có tên hành vi cụ thể và thực sự phục vụ ít nhất hai feature hoặc hạ tầng app.
- Tài liệu riêng mobile đặt trong `mobile/docs/` khi cần nhiều tài liệu; tên file dùng `lowercase-kebab-case.md` và mô tả rõ phân hệ, contract hoặc mục đích.
- File build, coverage, log, screenshot kiểm thử, patch và dữ liệu tạm phải ở nơi output phù hợp, được ignore và được dọn trước bàn giao; không commit như source of truth.
- Khi tạo, di chuyển hoặc đổi tên file, cập nhật đồng bộ import, route, composition root, test và tài liệu; không giữ hai bản cùng trách nhiệm.

## 18. Bảo Mật Client, Cấu Hình Và Logging

- Mobile, UI, route, field disabled, bộ lọc và mọi dữ liệu client gửi lên đều không đáng tin cậy; backend là ranh giới cuối cho authentication, authorization, validation, data scope và nghiệp vụ.
- Không hạ quyền, bỏ route guard, mở dữ liệu hoặc dùng mock có dữ liệu nhạy cảm chỉ để demo hoặc làm giao diện chạy.
- Mobile chỉ được chứa cấu hình công khai hoặc giá trị không gây rủi ro nếu bị trích xuất khỏi gói cài đặt; không chứa signing key, API secret, private key, credential dịch vụ hoặc connection string.
- Tách rõ Development, Staging và Production; base URL và cấu hình công khai phải được validate khi khởi động, không âm thầm fallback sang production khi cấu hình sai.
- Không log token, authorization header, mật khẩu, OTP, dữ liệu cá nhân nhạy cảm, payload đầy đủ hoặc response nhạy cảm; log Development phải ngắn gọn và được làm sạch trước bàn giao.
- Không đưa dữ liệu nhạy cảm vào analytics, clipboard, notification, deep link, URL, screenshot hoặc thông báo lỗi.
- Khi feature mở URL, deep link, file hoặc dữ liệu ngoài ứng dụng, phải validate scheme, host, kích thước, loại file và nội dung trước khi sử dụng; không tự bỏ qua lỗi TLS hoặc certificate.

## 19. Dependency Và Supply Chain

- Chỉ thêm package khi có use case cụ thể, đã kiểm tra package hiện có không giải quyết được và lợi ích lớn hơn chi phí bảo trì.
- Ưu tiên package chính thức, phổ biến, còn được duy trì, license phù hợp và tương thích với Flutter/Dart hiện tại; không thêm package chỉ để rút ngắn một đoạn code nhỏ.
- Không chạy upgrade hàng loạt hoặc thay lockfile ngoài phạm vi task. Khi dependency thay đổi, cập nhật `pubspec.yaml`, `pubspec.lock`, cấu hình nền tảng, code và test liên quan trong cùng thay đổi.
- Không thêm package tải hoặc thực thi mã động không kiểm soát, bỏ qua TLS, lưu secret plain text hoặc yêu cầu quyền nền tảng vượt nhu cầu nghiệp vụ.
- Khi phát hiện dependency lỗi thời hoặc có rủi ro nhưng chưa thể nâng cấp trong phạm vi, ghi rõ package, ảnh hưởng và hướng xử lý; không âm thầm bỏ qua.

## 20. Hiệu Năng Và Khả Năng Vận Hành

- Không gọi API trong `build`, trong vòng đời render hoặc từ rebuild không kiểm soát; không để một thao tác UI gửi request lặp.
- Search server phải debounce và bỏ qua hoặc hủy response cũ; danh sách lớn phải dùng phân trang, filter, sort ổn định và không tải toàn bộ dữ liệu chỉ để hiển thị một phần.
- Retry phải có giới hạn, không lặp vô hạn và không tự lặp thao tác ghi không idempotent; timeout và cancellation phải được xử lý ở ranh giới phù hợp.
- Không cache token, quyền, data scope hoặc dữ liệu nhạy cảm ngoài cơ chế đã xác nhận; cache phải có vòng đời, expiration và invalidation rõ.
- Tối ưu hiệu năng không được làm sai authorization, phạm vi công ty/trạm, dữ liệu hiển thị hoặc tính nhất quán với backend.
- Không thêm offline mode, background sync, queue, scheduled task hoặc hạ tầng phức tạp để chuẩn bị cho nhu cầu chưa được người dùng xác nhận.

## 21. Bảo Trì Và Tương Thích

- Ưu tiên thay đổi nhỏ, độc lập, dễ review và có thể kiểm tra; không refactor toàn bộ feature khi task chỉ yêu cầu một use case nhỏ.
- Không tạo source of truth thứ hai cho cùng contract, model, quyền, route hoặc quy tắc mapping; lịch sử thay đổi thuộc Git.
- Breaking change phải nêu rõ lý do, consumer bị ảnh hưởng, đường nâng cấp, khả năng tương thích ngược và cập nhật đồng bộ DTO, repository, controller, UI, test và tài liệu.
- Mock, placeholder hoặc hardcode được phép trong giai đoạn FE-first chỉ khi có ranh giới thay thế rõ và được người dùng xác nhận; không được tồn tại như giải pháp production lâu dài.
- Quyết định bền vững phải nằm trong code, test, contract, tài liệu hoặc `AGENTS.md`, không chỉ trong lịch sử hội thoại.
- Mỗi feature phải có đường đọc rõ từ route hoặc entry point tới controller, repository/data source, model/contract, screen và test liên quan.
- Khi sửa bug, cân nhắc regression test phù hợp; không sửa warning hoặc vấn đề ngoài phạm vi chỉ vì phát hiện trong lúc làm task khác.

## 22. Phối Hợp Agent Và Subagent

- Kế thừa đầy đủ mục 27, 28 và 29 của `D:\TTSmartApp\AGENTS.md`.
- Trước khi sửa, xác định rõ feature, thư mục, file, contract, phạm vi dữ liệu và lệnh kiểm tra; không để hai agent cùng sửa composition root, registry, lockfile hoặc cùng file khi chưa có owner điều phối.
- Agent mobile không sửa backend để làm UI chạy và không che breaking change bằng cách nới parsing hoặc authorization ở client, trừ khi người dùng giao rõ task xuyên dự án.
- Không ghi đè, reset, checkout đè hoặc hoàn tác thay đổi hợp lệ của agent khác khi chưa hiểu nguồn gốc và chưa được giao xử lý.
- Chỉ dùng subagent cho phần việc độc lập có phạm vi file và tiêu chí hoàn thành rõ; agent chính vẫn phải review diff, contract, test và file ngoài phạm vi trước khi tích hợp.
- Trước bàn giao, kiểm tra thay đổi thực tế, file ngoài phạm vi, file tạm, log, conflict, lockfile và cấu hình; không dùng lệnh Git phá hủy khi chưa có yêu cầu rõ.
