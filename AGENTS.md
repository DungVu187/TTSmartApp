# Hướng Dẫn Agent Toàn Dự Án TTSmartApp

## 1. Mục Tiêu Dự Án

- Xây dựng ứng dụng mobile nội bộ cho công ty trên nền database Microsoft SQL Server đã có sẵn.
- Phạm vi ưu tiên hiện tại là công ty quản lý tập trung nhiều trạm trộn, xem dữ liệu tổng hợp và theo dõi chi tiết từng trạm.
- Khả năng để người quản lý một trạm tự theo dõi trạm của mình là định hướng tương lai, không thuộc phạm vi mặc định của giai đoạn hiện tại.
- Không xây trước chế độ một trạm, cơ chế đồng bộ, cấu hình triển khai riêng hoặc luồng UI riêng nếu người dùng chưa yêu cầu; chỉ giữ ranh giới dữ liệu theo trạm đủ rõ để có thể mở rộng sau này.
- Database `dangnhap.net` là nguồn tham chiếu kỹ thuật và dữ liệu chuẩn của website hiện tại để hiểu cấu trúc, quan hệ dữ liệu, dữ liệu hợp lệ và phạm vi thông tin của hệ thống.
- Database `TTSmartMobile_Dev` là database làm việc dành cho phát triển và kiểm thử app; không được dùng `dangnhap.net` làm đích ghi.
- Nghiệp vụ của app mới có thể giống, kế thừa một phần hoặc khác website hiện tại; không mặc định phải sao chép nghiệp vụ web khi chưa có yêu cầu xác nhận.
- Triển khai lần lượt từng phân hệ nhỏ, hoàn thành trọn luồng từ database, backend, API đến mobile trước khi mở rộng sang phân hệ tiếp theo.
- Nghiệp vụ sẽ được làm rõ và điều chỉnh dần theo phản hồi của người dùng; không cố xây dựng toàn bộ hệ thống chỉ từ suy đoán ban đầu.
- Ưu tiên giải pháp đơn giản, chạy được, dễ kiểm tra và dễ mở rộng theo nghiệp vụ thực tế của công ty.

## 2. Nguyên Tắc Nguồn Thông Tin

Khi phân tích hoặc triển khai một chức năng, ưu tiên thông tin theo thứ tự sau:

1. Yêu cầu và xác nhận trực tiếp của người dùng.
2. Schema, constraint, quan hệ và dữ liệu hợp lệ trong database `dangnhap.net` để xác định mô hình dữ liệu kỹ thuật; mọi thao tác phát triển và kiểm thử phải dùng `TTSmartMobile_Dev`.
3. API contract, mã nguồn, test và tài liệu đã được xác nhận trong repository.
4. Hành vi thực tế của website công ty nếu sau này có thể truy cập hoặc được cung cấp tài liệu, chỉ dùng như nguồn tham khảo và đối chiếu.
5. Giả định tạm thời của agent, chỉ được dùng khi chưa có đủ thông tin và phải được ghi rõ khi bàn giao.

- Database là nguồn cơ sở quan trọng nhưng không tự động mô tả đầy đủ nghiệp vụ, phân quyền, ý nghĩa trạng thái, công thức tính hoặc quy trình thao tác của người dùng.
- Không suy diễn nghiệp vụ chỉ từ tên bảng hoặc tên cột nếu chưa kiểm tra constraint, quan hệ, dữ liệu mẫu và các database object liên quan.
- View, stored procedure, function, trigger và quy tắc dữ liệu cũ có thể phản ánh nghiệp vụ của website hiện tại, nhưng chỉ được xem là bằng chứng để phân tích, không tự động là yêu cầu bắt buộc của app mới.
- Nghiệp vụ mới có thể thay đổi so với website nếu người dùng xác nhận; vẫn phải bảo đảm tính toàn vẹn dữ liệu và đánh giá ảnh hưởng tới hệ thống đang dùng chung database.
- Khi các nguồn thông tin mâu thuẫn, không tự chọn phương án âm thầm; phải nêu rõ mâu thuẫn, mức ảnh hưởng và phương án đang áp dụng.
- Không tuyên bố một chức năng đã giống website nếu chưa có cơ sở để đối chiếu với website.

## 3. Phạm Vi Và Thứ Tự Ưu Tiên

- File này áp dụng cho toàn bộ workspace `TTSmartApp`.
- Khi làm việc trong `backend/`, phải đọc và tuân thủ thêm `backend/AGENTS.md`.
- Khi làm việc trong `mobile/`, phải đọc và tuân thủ thêm `mobile/AGENTS.md`.
- Quy tắc trong file gần mã nguồn hơn được ưu tiên cho chi tiết triển khai của khu vực đó, nhưng không được làm sai mục tiêu hoặc kiến trúc tổng thể trong file gốc.
- Yêu cầu trực tiếp của người dùng luôn có mức ưu tiên cao nhất.
- Chỉ thay đổi đúng phạm vi được yêu cầu; không tự ý sửa lỗi, warning hoặc tái cấu trúc phần không liên quan.

## 4. Trách Nhiệm Cập Nhật Các File AGENTS.md

- `AGENTS.md` gốc chứa định hướng toàn dự án, ranh giới kiến trúc và quy trình phối hợp backend-mobile.
- `backend/AGENTS.md` phải phản ánh đúng cấu trúc backend, quy tắc truy cập database, mapping EF Core, API và lệnh build/test hiện tại.
- `mobile/AGENTS.md` phải phản ánh đúng cấu trúc Flutter, state management, API client, điều hướng, UI và lệnh kiểm tra hiện tại.
- Trước khi sửa code trong `backend/` hoặc `mobile/`, agent phải kiểm tra file `AGENTS.md` tương ứng còn phù hợp với file tổng và trạng thái repository hay không.
- Khi phát hiện quy tắc bền vững mới, cấu trúc thực tế khác tài liệu, lệnh kiểm tra thay đổi hoặc hướng dẫn cũ không còn đúng, agent phải cập nhật file `AGENTS.md` gần mã nguồn nhất trong cùng phạm vi công việc.
- Nếu thay đổi ảnh hưởng cả hai phía, phải đánh giá và cập nhật đồng bộ `backend/AGENTS.md`, `mobile/AGENTS.md` và file gốc khi cần.
- Không đưa secret, thông tin production, trạng thái tạm thời của một task hoặc chi tiết quá nhỏ của một màn hình vào `AGENTS.md`.
- Không biến quy tắc riêng của một phân hệ, ví dụ nhân viên, thành mặc định cho toàn hệ thống. Khi chuyển phân hệ, phải rà soát và loại bỏ giả định không còn phù hợp trong hướng dẫn cấp dưới.

## 5. Kiến Trúc Tổng Thể

- Backend nằm trong `backend/`, sử dụng C# và ASP.NET Core Web API.
- Frontend mobile nằm trong `mobile/`, sử dụng Flutter và Dart.
- Database sử dụng Microsoft SQL Server và chỉ backend được phép truy cập trực tiếp.
- Website hiện tại và app dùng chung database nghiệp vụ khi triển khai; app không tạo database nghiệp vụ riêng và không xây cơ chế đồng bộ dữ liệu thay cho việc dùng chung nguồn dữ liệu.
- Trong môi trường phát triển, backend phải kết nối `TTSmartMobile_Dev`; `dangnhap.net` chỉ được kết nối để khảo sát read-only hoặc đối chiếu khi được phép.
- Backend ưu tiên Entity Framework Core; có thể dùng view hoặc stored procedure hiện hữu khi đó là phần cần thiết của nghiệp vụ.
- Luồng chuẩn là `Flutter -> HTTPS/JSON REST API -> ASP.NET Core -> EF Core hoặc database object an toàn -> SQL Server`.
- Flutter không được kết nối trực tiếp SQL Server và không được chứa connection string, tài khoản database hoặc chi tiết schema nội bộ.
- OpenAPI/Swagger của backend là hợp đồng tích hợp chính giữa backend và mobile sau khi được cập nhật và xác minh.

## 6. Mô Hình Vận Hành Và Phạm Vi Trạm

Trong giai đoạn hiện tại, mọi task mặc định phục vụ mô hình công ty quản lý nhiều trạm. Hệ thống vẫn phải xem `công ty`, `trạm trộn`, `người dùng` và `phạm vi dữ liệu` là các khái niệm riêng, kể cả khi database hiện tại chưa thể hiện đầy đủ.

### Phạm vi triển khai hiện tại: công ty quản lý nhiều trạm

- Người dùng cấp công ty có thể xem dữ liệu tổng hợp và đi vào chi tiết từng trạm theo quyền được cấp.
- Các màn hình danh sách, dashboard, báo cáo và bộ lọc phải xác định rõ đang hiển thị toàn công ty, một nhóm trạm hay một trạm cụ thể.
- Việc chọn trạm trên mobile chỉ thay đổi phạm vi yêu cầu; backend vẫn phải xác minh người dùng có quyền truy cập trạm đó.
- Truy vấn tổng hợp nhiều trạm phải xử lý rõ múi giờ, kỳ báo cáo, đơn vị đo, mã trạm và khả năng dữ liệu giữa các trạm không đồng nhất.

### Định hướng tương lai: một trạm trên máy trạm

- Sau khi mô hình công ty hoạt động ổn định, hệ thống có thể được mở rộng để người quản lý trạm chỉ theo dõi trạm của mình.
- Agent không được tự triển khai chế độ này, tách ứng dụng, thêm local database, offline mode, đồng bộ hai chiều hoặc cấu hình máy trạm trong task hiện tại.
- Khi người dùng chính thức yêu cầu phát triển chế độ một trạm, phải khảo sát lại kiến trúc triển khai, database, authentication, data scope và cập nhật các file `AGENTS.md` trước khi code.
- Code hiện tại chỉ cần tránh ghi cứng giả định khiến dữ liệu của các trạm bị trộn lẫn hoặc không thể giới hạn theo trạm về sau.

### Nguyên tắc chung

- Không mặc định database hiện có là database nhiều trạm hay mỗi trạm có một database riêng. Phải khảo sát schema, dữ liệu và cách triển khai thực tế trước khi chọn mô hình truy cập.
- Nếu phát hiện mỗi máy trạm có database riêng, phải báo cáo đây là vấn đề kiến trúc cần xác nhận; không tự xây cơ chế tổng hợp hoặc đồng bộ dữ liệu.
- Nếu một database chứa nhiều trạm, mọi truy vấn và thao tác ghi phải có điều kiện phạm vi trạm phù hợp và được kiểm tra tại backend.
- Không tin cậy `stationId`, `companyId` hoặc mã phạm vi do mobile gửi lên nếu chưa đối chiếu với danh tính, quyền hoặc cấu hình phía server.
- Không dùng lọc dữ liệu trên UI làm cơ chế bảo mật. Backend phải thực thi data scope cho danh sách, chi tiết, cập nhật, xóa, báo cáo và export.
- Khi thêm một phân hệ, mặc định thiết kế cho người dùng cấp công ty quản lý và theo dõi nhiều trạm; chỉ thiết kế luồng một trạm khi có yêu cầu riêng.

## 7. Phát Triển Theo Từng Phân Hệ

Không tạo hàng loạt entity, API và màn hình cho toàn bộ database ngay từ đầu. Mỗi phân hệ phải được triển khai theo một vertical slice hoàn chỉnh:

1. **Chốt phạm vi:** xác định chức năng nhỏ, người dùng cấp công ty, phạm vi toàn công ty hoặc trạm cụ thể, thao tác chính và kết quả mong đợi.
2. **Khảo sát database:** xác định bảng, view, stored procedure, function, trigger, khóa, quan hệ, index, default, nullable, kiểu dữ liệu và dữ liệu mẫu liên quan.
3. **Làm rõ nghiệp vụ:** phân biệt quan hệ dữ liệu lấy từ `dangnhap.net`, nghiệp vụ đã được người dùng xác nhận, hành vi web chỉ để tham khảo và điều còn chưa biết.
4. **Thiết kế contract:** xác định endpoint, HTTP method, request, response, validation, status code, lỗi, phân trang và quyền truy cập nếu có.
5. **Triển khai backend:** map đúng phần schema cần dùng, thực hiện validation và nghiệp vụ, cung cấp API ổn định.
6. **Triển khai mobile:** tích hợp API qua data layer, xây dựng UI phù hợp mobile và xử lý đầy đủ trạng thái.
7. **Kiểm tra xuyên suốt:** kiểm tra dữ liệu từ database đến API và UI, gồm thành công, dữ liệu rỗng, dữ liệu sai, lỗi mạng và lỗi quyền nếu có.
8. **Ghi nhận kết quả:** báo cáo giả định, nghiệp vụ đã xác nhận, phần chưa rõ, contract đã dùng và bước nhỏ tiếp theo.

- Ưu tiên hoàn thành một luồng sử dụng có giá trị thực tế trước khi mở rộng thêm nhiều màn hình hoặc bảng dữ liệu.
- Nếu chưa đủ thông tin nghiệp vụ, triển khai phần chắc chắn và giữ thiết kế dễ điều chỉnh; không che giấu giả định trong code.
- Không tạo placeholder, TODO hoặc mock vĩnh viễn thay cho logic thật. Mock chỉ dùng có chủ đích khi UI chưa có API và phải được nhận diện rõ.

## 8. Quan Hệ Với Website Hiện Tại

- Website hiện tại không phải nguồn đặc tả bắt buộc và không phải điều kiện để bắt đầu phát triển app.
- Khi chưa biết website có những chức năng gì, bắt đầu từ `dangnhap.net`, nhu cầu quản lý nhiều trạm và yêu cầu được người dùng xác nhận.
- App và website được định hướng dùng chung database nghiệp vụ; phải giữ tương thích với dữ liệu, tài khoản và quy tắc hiện có, nhưng không tự động coi mọi hành vi web cũ là yêu cầu bắt buộc của app.
- Nếu sau này truy cập được website, có thể khảo sát tên chức năng, trường dữ liệu, bộ lọc, trạng thái, validation, phân quyền và quy trình để đối chiếu.
- Chỉ kế thừa hành vi web khi hành vi đó phù hợp và được xác nhận cho app mới; có thể thiết kế nghiệp vụ khác web khi có lý do rõ ràng.
- Không tự bổ sung một chức năng chỉ vì database hoặc website cũ có chức năng tương ứng.
- Giao diện Flutter phải được thiết kế cho mobile, không thu nhỏ nguyên bố cục desktop để đưa vào màn hình điện thoại.

## 9. Quy Tắc Database Hiện Có

- Database `dangnhap.net` là nguồn tham chiếu kỹ thuật và dữ liệu chuẩn của website hiện tại; chỉ được khảo sát read-only để hiểu bảng, khóa, quan hệ, kiểu dữ liệu, dữ liệu hợp lệ và database object liên quan.
- Tuyệt đối không dùng `dangnhap.net` làm đích ghi. Không chạy `INSERT`, `UPDATE`, `DELETE`, `ALTER`, `DROP`, migration, seeder, restore hoặc bất kỳ thao tác thay đổi schema/dữ liệu nào lên database này.
- Database `TTSmartMobile_Dev` là database làm việc cho phát triển, kiểm thử và các thao tác ghi của app trong môi trường dev. Khi cần có baseline từ `dangnhap.net`, phải tạo bản làm việc an toàn theo quy trình được xác nhận, không sửa database nguồn.
- Script khởi tạo hoặc phục hồi database chỉ được tạo mới database đích. Nếu database hoặc đối tượng đích đã tồn tại, script phải từ chối và dừng; không được drop, ghi đè, merge ngầm hoặc tự động reset.
- Luồng reset/restore `TTSmartMobile_Dev` là thao tác riêng và nguy hiểm: phải có xác nhận rõ ràng trước khi thực hiện, backup toàn bộ database làm việc trước, kiểm tra backup thành công rồi mới được phục hồi. Nếu backup thất bại hoặc không xác minh được thì phải dừng.
- Nếu cần attach, restore hoặc tạo bản clone local để đọc database, phải tuân thủ `backend/AGENTS.md`, dùng bản sao an toàn và phân biệt rõ nguồn `dangnhap.net` với đích làm việc `TTSmartMobile_Dev`.
- Không chỉnh sửa trực tiếp file `.mdf`, `.ldf`, bản backup hoặc artifact database trong repository.
- Backend chỉ map các bảng và database object cần cho phân hệ đang làm; không scaffold toàn bộ database nếu người dùng chưa yêu cầu.
- Với mỗi phân hệ, phải xác định dữ liệu thuộc trạm nào bằng khóa, quan hệ, cấu hình database hoặc quy tắc đã được xác nhận; không suy đoán phạm vi từ tên trường.
- Phải giữ đúng tên bảng, tên cột, kiểu dữ liệu, độ dài, precision, nullable, khóa và quan hệ của schema hiện hữu khi mapping.
- Trước khi triển khai, phải kiểm tra view, stored procedure, function, trigger, computed column và constraint để hiểu hành vi dữ liệu hiện tại; chỉ kế thừa logic đó khi phù hợp với nghiệp vụ app đã xác nhận.
- Không dùng `EnsureCreated` cho database ứng dụng hiện hữu nếu việc đó có thể thay đổi hoặc ghi đè dữ liệu.
- Nếu cần thay đổi schema hoặc dữ liệu của `TTSmartMobile_Dev`, phải nêu rõ lý do, ảnh hưởng, khả năng tương thích và kế hoạch backup; không được suy diễn rằng có thể áp dụng cùng thao tác đó lên `dangnhap.net`.
- Dùng truy vấn tham số hóa qua EF Core hoặc API an toàn tương đương; không nối chuỗi SQL từ dữ liệu người dùng.
- Không ghi cứng hoặc commit secret, token, mật khẩu hay connection string production.

## 10. Quy Tắc Backend

- Làm việc chủ yếu trong `backend/` và tuân thủ `backend/AGENTS.md`.
- Chịu trách nhiệm ASP.NET Core, C#, REST API, validation, nghiệp vụ, xác thực, phân quyền, EF Core và tích hợp SQL Server.
- Giữ controller mỏng; đặt nghiệp vụ trong service hoặc feature phù hợp với cấu trúc hiện tại.
- Dùng DTO riêng cho request và response; không trả trực tiếp entity EF Core qua API.
- Dùng API bất đồng bộ và truyền `CancellationToken` qua các tầng liên quan.
- Chỉ map schema cần thiết cho phân hệ hiện tại và kiểm tra kỹ hành vi của database object liên quan.
- Validation, authorization và quy tắc bảo toàn dữ liệu quan trọng phải được thực thi ở backend.
- Backend phải xác định và thực thi phạm vi công ty/trạm trước khi đọc hoặc thay đổi dữ liệu; không dựa riêng vào bộ lọc do mobile gửi lên.
- Trong môi trường phát triển, mọi thao tác ghi của backend phải hướng vào `TTSmartMobile_Dev`; phải có biện pháp cấu hình hoặc kiểm tra để tránh trỏ nhầm tới `dangnhap.net`.
- Trả lỗi nhất quán, ưu tiên ASP.NET Core `ProblemDetails`.
- Cập nhật OpenAPI/Swagger khi endpoint hoặc API contract thay đổi.
- Không sửa mã Flutter trừ khi người dùng yêu cầu thay đổi xuyên dự án hoặc cần đồng bộ contract hai phía.

## 11. Quy Tắc Mobile

- Làm việc chủ yếu trong `mobile/` và tuân thủ `mobile/AGENTS.md`.
- Chịu trách nhiệm Flutter, Dart, UI, điều hướng, quản lý trạng thái, DTO, API client, repository và xử lý lỗi.
- Chỉ giao tiếp với backend qua HTTPS REST API.
- Không phụ thuộc trực tiếp vào entity EF Core, tên bảng hoặc cấu trúc nội bộ SQL Server.
- Không gọi HTTP trực tiếp trong widget hoặc màn hình; đặt network call sau API client hoặc data source.
- Tách DTO giao tiếp API khỏi model hoặc state UI khi chúng có mục đích khác nhau.
- Quản lý tập trung base URL, timeout, header, xác thực, serialization và chuyển đổi lỗi.
- Xử lý đầy đủ loading, empty, success, validation error, network error, unauthorized và retry khi phù hợp.
- UI phải thể hiện rõ đang xem toàn công ty hay trạm nào và cung cấp cách chuyển phạm vi phù hợp với quyền của người dùng.
- Validation phía Flutter phục vụ trải nghiệm người dùng; không thay thế validation và authorization ở backend.
- Không sửa controller, service, migration hoặc database trừ khi người dùng yêu cầu thay đổi xuyên dự án.

## 12. Hợp Đồng API

- API trao đổi JSON và mặc định dùng tên thuộc tính `camelCase`.
- Timestamp có thời gian dùng ISO 8601 và UTC; trường chỉ có ngày dùng định dạng `yyyy-MM-dd`.
- Giữ ổn định endpoint, HTTP method, status code, field, kiểu dữ liệu, nullable, enum, phân trang và response envelope.
- Không xóa hoặc đổi field đang được mobile sử dụng nếu chưa đánh giá tương thích ngược.
- Khi contract chưa rõ, phải kiểm tra DTO, controller, OpenAPI hoặc JSON thực tế; không suy đoán chỉ từ schema SQL Server.
- Thay đổi phá vỡ tương thích phải được nêu rõ và cập nhật đồng bộ backend, OpenAPI, DTO Flutter, parsing, UI và test liên quan.
- Không để mobile phải hiểu tên bảng, stored procedure hoặc quy tắc mapping nội bộ của backend.
- API liên quan dữ liệu vận hành phải xác định rõ phạm vi trạm lấy từ authentication, cấu hình server hay tham số đã được authorization kiểm tra.

## 13. Quy Trình Thay Đổi Xuyên Dự Án

1. Xác định phân hệ, use case cấp công ty và phạm vi toàn công ty hoặc từng trạm liên quan.
2. Khảo sát schema và hành vi database hiện có.
3. Chốt hoặc ghi rõ giả định nghiệp vụ.
4. Xác định và cập nhật API contract.
5. Cập nhật backend, validation và data access.
6. Cập nhật DTO, API client, repository, state và UI Flutter.
7. Kiểm tra nullable, enum, ngày giờ, lỗi, phân trang và tương thích ngược.
8. Cập nhật `AGENTS.md` liên quan nếu có quy tắc bền vững mới.
9. Chạy kiểm tra hẹp nhất trước, sau đó mới chạy build và test rộng hơn.

## 14. Kiểm Tra Trước Khi Bàn Giao

- Backend: chạy test liên quan trước, sau đó chạy `dotnet test backend/TTSmart.sln` và `dotnet build backend/TTSmart.sln` khi môi trường hỗ trợ.
- Flutter: format file đã sửa, sau đó chạy `dart format .`, `flutter analyze` và `flutter test` liên quan trong `mobile/` khi môi trường hỗ trợ.
- Với thay đổi liên quan database, kiểm tra mapping, câu truy vấn và SQL dự kiến; không áp dụng bất kỳ thay đổi nào lên `dangnhap.net`.
- Với script tạo hoặc phục hồi database, kiểm tra script từ chối database đích đã tồn tại và không có hành vi drop/ghi đè. Với luồng reset `TTSmartMobile_Dev`, kiểm tra có xác nhận rõ ràng và backup thành công trước khi restore.
- Với thay đổi contract, kiểm tra OpenAPI, serialization và parsing ở cả backend lẫn mobile.
- Với chức năng có phạm vi trạm, kiểm tra tối thiểu quyền xem đúng trạm, từ chối truy cập chéo trạm và hành vi khi người dùng không truyền hoặc cố thay đổi mã trạm.
- Báo cáo rõ file đã thay đổi, nghiệp vụ đã xác nhận, giả định còn lại, thay đổi database, kết quả kiểm tra và phần chưa thể xác minh.
- Không bàn giao placeholder, TODO thay cho logic thật, method chưa hoàn thiện hoặc code lỗi bị comment lại.

## 15. Bảo Mật Và Dữ Liệu Công Ty

- Không log secret, token, connection string, mật khẩu hoặc dữ liệu cá nhân nhạy cảm.
- Không đưa thông tin production vào source code, test fixture, ảnh chụp, tài liệu mẫu hoặc file `AGENTS.md`.
- Không sao chép dữ liệu thật không cần thiết vào test; phải ẩn danh dữ liệu khi cần tạo fixture.
- Không hiển thị payload lỗi thô, stack trace hoặc chi tiết hạ tầng nội bộ trên ứng dụng production.
- Thực thi validation và authorization quan trọng tại backend; kiểm tra phía Flutter chỉ hỗ trợ trải nghiệm người dùng.

## 16. Nguyên Tắc Bàn Giao

- Nêu ngắn gọn chức năng đã hoàn thành và phân hệ bị ảnh hưởng.
- Liệt kê các file chính đã thay đổi.
- Nêu nguồn dữ liệu hoặc database object đã sử dụng để xây dựng chức năng.
- Phân biệt rõ nghiệp vụ đã được xác nhận và giả định tạm thời.
- Báo cáo kết quả build, test, analyze và phần chưa thể chạy trong môi trường hiện tại.
- Đề xuất bước nhỏ tiếp theo theo đúng thứ tự ưu tiên, không tự mở rộng phạm vi ngoài yêu cầu.

## 17. Tổ Chức Cấu Trúc Thư Mục, File Và Quy Ước Đặt Tên

Mục tiêu của phần này là để người mới tiếp quản có thể xác định nhanh nơi cần đọc, nơi cần sửa và phạm vi ảnh hưởng của một thay đổi mà không phải tìm kiếm toàn bộ repository.

### 17.1. Nguyên Tắc Tổ Chức Chung

- Tổ chức mã nguồn theo **phân hệ nghiệp vụ** và **trách nhiệm kỹ thuật**, không tổ chức theo tên người làm, tên task, ngày thực hiện hoặc trạng thái tạm thời.
- Mỗi file phải có một trách nhiệm chính có thể mô tả ngắn gọn; không gom nhiều nghiệp vụ không liên quan vào một file chỉ vì dùng chung ngôn ngữ hoặc framework.
- Đặt code gần phân hệ sở hữu nó nhất. Chỉ đưa vào khu vực dùng chung khi thành phần thực sự được ít nhất hai phân hệ sử dụng và không chứa quy tắc nghiệp vụ riêng của một phân hệ.
- Không tạo thư mục cấp cao mới nếu chưa có mục đích bền vững, ranh giới rõ và vị trí đó không thể nằm hợp lý trong `backend/`, `mobile/` hoặc khu vực tài liệu hiện có.
- Không tạo sẵn hàng loạt thư mục, layer hoặc file rỗng cho nhu cầu tương lai. Chỉ tạo cấu trúc cần cho vertical slice đang triển khai.
- Không giữ nhiều bản của cùng một logic bằng hậu tố như `old`, `new`, `final`, `final2`, `copy`, `backup` hoặc `temp`; lịch sử thay đổi thuộc về Git.
- Trước khi tạo file mới, phải tìm kiếm file hoặc abstraction tương đương để tránh trùng DTO, model, helper, validator, service, repository hoặc quy tắc mapping.
- Khi cấu trúc thực tế thay đổi bền vững, phải cập nhật `AGENTS.md` gần mã nguồn nhất và tài liệu điều hướng liên quan trong cùng thay đổi.

### 17.2. Ranh Giới Thư Mục Toàn Repository

- Thư mục gốc chỉ chứa tài liệu và cấu hình dùng chung toàn dự án như `AGENTS.md`; không đặt source code backend, Dart, SQL nghiệp vụ hoặc file tạm trực tiếp ở thư mục gốc.
- `backend/` chứa toàn bộ ASP.NET Core, C#, EF Core, API contract backend, script phục vụ backend và test backend; tuân thủ thêm `backend/AGENTS.md`.
- `mobile/` chứa toàn bộ Flutter, Dart, asset mobile, cấu hình nền tảng và test mobile; tuân thủ thêm `mobile/AGENTS.md`.
- `DataSQL/` chỉ là khu vực artifact database được cung cấp để tham chiếu hoặc phục vụ quy trình database đã được xác nhận; không đặt source code ứng dụng, DTO, tài liệu phân hệ, log chạy thử hoặc script tạm vào đây và không chỉnh sửa trực tiếp `.mdf`, `.ldf`, `.bak`.
- Tài liệu kỹ thuật thuộc riêng backend đặt trong `backend/docs/`; script khảo sát, kiểm tra hoặc vận hành backend đặt trong `backend/scripts/`.
- Tài liệu chỉ dành cho mobile đặt trong `mobile/README.md` hoặc `mobile/docs/` khi số lượng đủ lớn để cần thư mục riêng; không rải tài liệu mobile vào các thư mục widget, model hoặc platform.
- Test phải nằm trong cây test của nền tảng tương ứng và phản chiếu tên phân hệ hoặc thành phần nguồn; không đặt test cạnh file production nếu cấu trúc hiện tại của nền tảng không dùng cách đó.
- File sinh ra khi build, log, patch tạm, kết quả profile, coverage và dữ liệu chạy thử phải nằm trong thư mục output tạm phù hợp và được ignore; không xem chúng là source of truth hoặc commit như mã nguồn chính thức.

### 17.3. Cấu Trúc Backend Định Hướng

Trong `backend/src/TTSmart.Api/`, tiếp tục cấu trúc hiện tại và áp dụng các ranh giới sau:

- `Controllers/` chỉ chứa HTTP entry point, binding request, gọi service, authorization ở mức endpoint và trả response; không chứa truy vấn EF Core hoặc nghiệp vụ dài.
- `Features/<FeatureName>/` chứa contract, service, validator, mapper và hỗ trợ riêng của một phân hệ, ví dụ `Features/AccessManagement/`; không tạo một thư mục `Services/` chung chứa mọi nghiệp vụ của toàn hệ thống.
- `Data/<DataArea>/` chứa `DbContext`, entity mapping, convention và truy cập database gắn với một vùng dữ liệu kỹ thuật rõ ràng; không đặt API DTO hoặc UI-oriented model tại đây.
- `Common/` chỉ chứa thành phần kỹ thuật dùng chung ổn định như exception, pagination, security helper hoặc OpenAPI support; không đưa logic riêng của một phân hệ vào `Common/` để tiện gọi.
- `Program.cs` là composition root để đăng ký dependency, middleware và endpoint; không đặt nghiệp vụ hoặc truy vấn dữ liệu trong file này.
- `backend/tests/TTSmart.Api.Tests/` chứa test backend; khi số lượng test của một phân hệ tăng, tổ chức thư mục test phản chiếu `Features/<FeatureName>/`, `Controllers/` hoặc `Data/<DataArea>/` thay vì dồn tất cả vào một thư mục phẳng.
- Nếu một file contract hoặc support bắt đầu chứa nhiều nhóm kiểu độc lập, thay đổi vì các lý do khác nhau hoặc gây khó tìm kiếm, phải tách theo đối tượng hoặc use case; không tiếp tục mở rộng file tổng hợp chỉ để giảm số lượng file.

### 17.4. Cấu Trúc Mobile Định Hướng

Trong `mobile/lib/`, tiếp tục tổ chức theo feature-first:

- `core/` chỉ chứa hạ tầng hoặc thành phần dùng chung thực sự như network, config, storage, theme, utility và widget nền; không đặt model, state hoặc widget mang nghiệp vụ riêng của một phân hệ tại đây.
- `features/<feature_name>/` là ranh giới chính của mỗi phân hệ, ví dụ `features/access_management/`; mỗi phân hệ tự sở hữu data layer, state/controller và UI của mình.
- `features/<feature_name>/data/` chứa DTO/model giao tiếp API, data source và repository của phân hệ; không gọi HTTP trực tiếp từ `presentation/`.
- `features/<feature_name>/presentation/` chứa controller/state, screen, dialog và widget của phân hệ; widget không được biết chi tiết bảng SQL hoặc entity EF Core.
- Chỉ thêm `domain/` khi phân hệ có model hoặc use case nghiệp vụ độc lập với API/UI và việc tách layer làm code rõ hơn; không tạo layer rỗng để đủ mẫu kiến trúc.
- Widget dùng riêng cho một màn hình đặt gần màn hình đó hoặc trong thư mục widget của cùng phân hệ; chỉ chuyển sang `core/widgets/` khi đã có nhu cầu dùng chung rõ ràng ở nhiều phân hệ.
- `mobile/test/features/<feature_name>/` phản chiếu phân hệ production; test cho `core/` đặt trong `mobile/test/core/`.
- Không tiếp tục tạo file nhóm quá rộng như `models.dart`, `controllers.dart` hoặc `utils.dart` nếu các thành phần bên trong có thể phát triển độc lập; file nhóm chỉ phù hợp khi các kiểu nhỏ, liên kết chặt và luôn thay đổi cùng nhau.

### 17.5. Cách Xác Định File Cần Sửa Hoặc Nơi Đặt File Mới

Khi tiếp nhận một thay đổi, xác định vị trí theo thứ tự sau:

1. Xác định phân hệ nghiệp vụ sở hữu use case, ví dụ authentication, access management hoặc một phân hệ vận hành theo trạm.
2. Xác định tầng chịu trách nhiệm: API entry point, nghiệp vụ, data access, API DTO, mobile repository, state/controller, UI hay test.
3. Sửa file đang là source of truth của trách nhiệm đó; không chép logic sang file mới chỉ để tránh hiểu code hiện tại.
4. Nếu chưa có file phù hợp, tạo file trong phân hệ và layer tương ứng, dùng tên thể hiện đối tượng cùng trách nhiệm.
5. Chỉ tạo abstraction dùng chung sau khi xác nhận có ít nhất hai nơi sử dụng thực tế và tên abstraction mô tả đúng hành vi chung.
6. Cập nhật test phản chiếu thành phần đã sửa và tài liệu contract nếu thay đổi ảnh hưởng tích hợp backend-mobile.

Ví dụ định vị trách nhiệm:

- Đổi route, HTTP method, status code hoặc binding request: kiểm tra controller và API contract backend.
- Đổi validation hoặc nghiệp vụ: kiểm tra service/validator trong `Features/<FeatureName>/`, không xử lý riêng ở controller hoặc widget.
- Đổi bảng, cột, quan hệ hoặc truy vấn EF Core: kiểm tra `Data/<DataArea>/` và service sử dụng nó.
- Đổi JSON request/response: cập nhật contract backend, DTO backend, model/repository mobile, parsing và test liên quan.
- Đổi cách hiển thị hoặc tương tác: kiểm tra `presentation/` của đúng feature; không sửa `core/` nếu hành vi chỉ thuộc một màn hình.
- Đổi thành phần hạ tầng dùng chung: kiểm tra `Common/` phía backend hoặc `core/` phía mobile và đánh giá ảnh hưởng tới mọi nơi đang sử dụng.

### 17.6. Quy Ước Đặt Tên Chung

- Tên phải mô tả được **đối tượng nghiệp vụ** và **vai trò của file**; ưu tiên tên cụ thể như `UserAdministrationService.cs` hoặc `user_detail_screen.dart` thay cho `Manager.cs`, `Helper.cs`, `CommonService.cs`, `screen.dart` hoặc `data.dart`.
- Tên source file và thư mục không dùng dấu tiếng Việt, khoảng trắng hoặc ký tự khó dùng trên nhiều hệ điều hành.
- Một phân hệ phải dùng cùng một tên chuẩn xuyên suốt repository, chỉ chuyển đổi theo quy ước ngôn ngữ: `AccessManagement` trong C#, `access_management` trong Dart và `access-management` trong tên tài liệu hoặc script.
- Tên file phải khớp với thành phần chính bên trong. Nếu file chứa một public class chính, tên file phải trùng tên class theo quy ước của ngôn ngữ.
- Không dùng tên chỉ thể hiện trạng thái phát triển như `new_api`, `fixed_service`, `latest_screen`, `test2` hoặc `final_contract`; tên phải tiếp tục đúng sau nhiều lần sửa.
- Không thêm số phiên bản vào tên source file như `ServiceV2` nếu chưa có chiến lược versioning thật sự; ưu tiên thay đổi tương thích hoặc version API ở ranh giới contract đã được xác nhận.
- Chỉ thêm ngày vào tên file khi đó là snapshot, báo cáo hoặc artifact cần lưu theo thời điểm; dùng định dạng rõ ràng `yyyyMMdd`, ví dụ `auth-schema-snapshot-20260724.txt`.

### 17.7. Quy Ước Tên Backend C#

- Thư mục, namespace, class, record, enum và tên file C# dùng `PascalCase` theo convention .NET hiện tại.
- Interface bắt đầu bằng `I`, ví dụ `IAuthService.cs`; implementation dùng tên vai trò cụ thể, ví dụ `AuthService.cs`.
- Controller kết thúc bằng `Controller`; service kết thúc bằng `Service`; option cấu hình kết thúc bằng `Options`; exception kết thúc bằng `Exception`.
- DTO nhận dữ liệu dùng hậu tố `Request`; DTO trả dữ liệu dùng hậu tố `Response`; kiểu trung gian chỉ dùng `Dto` khi không thể đặt tên nghiệp vụ cụ thể hơn.
- Validator, mapper, policy, requirement và handler phải có hậu tố tương ứng để người đọc nhận ra trách nhiệm mà không cần mở file.
- Test class và file dùng hậu tố `Tests`, ví dụ `AuthServiceTests.cs`; fixture/factory dùng hậu tố mô tả vai trò như `Factory`, `Fixture` hoặc `Builder`.
- File tổng hợp như `AccessManagementContracts.cs` chỉ nên chứa nhóm contract nhỏ và liên kết chặt. Khi từng contract có vòng đời riêng, tách thành file theo tên request/response hoặc use case.

### 17.8. Quy Ước Tên Mobile Dart/Flutter

- Thư mục và file Dart dùng `lowercase_with_underscores`; class, enum và widget dùng `UpperCamelCase`; biến, method và property dùng `lowerCamelCase`.
- Screen dùng hậu tố `_screen.dart`; dialog dùng `_dialog.dart`; repository dùng `_repository.dart`; controller dùng `_controller.dart`; service hoặc data source dùng hậu tố phản ánh đúng vai trò.
- Tên widget phải thể hiện nội dung hoặc hành vi, ví dụ `StationScopeSelector`, không dùng tên chung như `CustomWidget`, `CommonCard` hoặc `MyComponent`.
- Model hoặc DTO mới ưu tiên một file theo đối tượng hoặc nhóm contract cùng use case. Chỉ dùng file nhóm như `auth_models.dart` khi các kiểu nhỏ và luôn thay đổi cùng nhau.
- Test dùng hậu tố `_test.dart` và phản chiếu tên file hoặc hành vi được kiểm tra, ví dụ `auth_repository_test.dart`.
- Không đặt từ `page` và `screen` lẫn lộn cho cùng một khái niệm trong một phân hệ; dự án hiện dùng `screen`, vì vậy file mới tiếp tục dùng `screen` trừ khi `mobile/AGENTS.md` thay đổi convention.

### 17.9. Quy Ước Tên Tài Liệu, Script Và Artifact

- Giữ nguyên tên chuẩn `AGENTS.md` cho hướng dẫn agent và `README.md` cho tài liệu nhập môn của một phạm vi.
- Tài liệu mới ưu tiên tên `lowercase-kebab-case.md` mô tả rõ phân hệ và mục đích, ví dụ `access-management-api-contract.md`; không tạo tên chung như `notes.md`, `document.md` hoặc `report-final.md`.
- Script PowerShell và SQL mới dùng `lowercase-kebab-case` theo dạng động từ-phạm vi, ví dụ `run-auth-e2e.ps1`, `discover-web-auth-schema.sql` hoặc `verify-station-scope.sql`.
- Tên script phải cho biết hành động có khả năng ghi dữ liệu hay chỉ đọc. Script nguy hiểm phải có tên rõ như `reset-...`, `restore-...` hoặc `delete-...` và vẫn phải tuân thủ quy trình xác nhận, backup và kiểm tra database đích.
- Artifact snapshot hoặc báo cáo có ngày phải dùng tên ổn định, chỉ thêm ngày khi cần phân biệt thời điểm; không đưa file log chạy thử hoặc output dùng một lần vào thư mục tài liệu chính thức.
- Không đổi tên hàng loạt file cũ chỉ để đồng bộ convention nếu không thuộc phạm vi task. Khi chạm tới file cũ có tên chưa tốt, chỉ đổi tên nếu việc đổi giúp bảo trì rõ rệt và phải cập nhật toàn bộ reference, test và tài liệu liên quan.

### 17.10. Kiểm Soát Kích Thước Và Phụ Thuộc

- Tách file khi nó chứa nhiều trách nhiệm không liên quan, nhiều nhóm public type phát triển độc lập, thường xuyên gây conflict hoặc khiến người đọc khó xác định nơi sửa; không tách máy móc chỉ dựa vào số dòng.
- Không tạo file `Helpers`, `Utils`, `Common` hoặc `Shared` như nơi chứa logic chưa biết đặt ở đâu. Thành phần dùng chung vẫn phải có tên theo hành vi cụ thể, ví dụ `DateTimeFormat`, `ClaimsPrincipalExtensions` hoặc `JsonHelpers`.
- Backend giữ hướng phụ thuộc từ HTTP entry point tới feature service rồi tới data access; data mapping không phụ thuộc controller hoặc API response model.
- Mobile giữ hướng phụ thuộc từ presentation tới repository/data layer và hạ tầng `core`; `core` không phụ thuộc ngược vào một feature cụ thể.
- Không để hai phân hệ truy cập trực tiếp state nội bộ của nhau. Nếu cần phối hợp, dùng contract, navigation argument, app-level state hoặc abstraction đã được xác định rõ.
- Tránh circular dependency, import xuyên sâu vào file nội bộ của feature khác và duplicate model chỉ khác tên nhưng cùng contract.

### 17.11. Quy Tắc Khi Tạo, Di Chuyển Hoặc Đổi Tên File

- Trước khi tạo file, xác nhận chưa có file cùng trách nhiệm và tên mới phù hợp với convention của thư mục đích.
- Khi di chuyển hoặc đổi tên, cập nhật đồng bộ namespace, import, route, dependency injection, test, script, tài liệu và mọi reference liên quan; không để cả file cũ và file mới cùng tồn tại như hai source of truth.
- Không thực hiện refactor đổi tên hàng loạt ngoài phạm vi chức năng đang làm nếu chưa được yêu cầu; ưu tiên thay đổi nhỏ, có thể kiểm tra và không làm khó việc review.
- Không để file rỗng, placeholder, TODO kiến trúc hoặc thư mục không có nội dung sau khi hoàn thành task.
- Không tạo `README.md` trong mọi thư mục nhỏ. Chỉ thêm tài liệu điều hướng khi cấu trúc không thể hiểu rõ từ tên file, có quy trình đặc biệt hoặc có nhiều entry point cần giải thích.
- Khi thêm phân hệ mới, phần bàn giao phải nêu rõ entry point backend, service nghiệp vụ, data source/database object, contract, repository/controller mobile, screen chính và test để người sau biết bắt đầu đọc từ đâu.

## 18. Nguyên Tắc Kiến Trúc Bảo Mật

Các quy tắc trong mục này bổ sung cho mục 15 và áp dụng xuyên suốt database, backend, API, mobile, test và vận hành:

- Không tin cậy mobile, UI, request, field ẩn hoặc disabled, route, bộ lọc hay bất kỳ dữ liệu nào do client gửi lên.
- Backend là ranh giới bảo mật cuối cùng đối với authentication, authorization, validation, data scope, business rule và tính toàn vẹn dữ liệu.
- Không dùng việc ẩn menu, nút, route hoặc màn hình làm cơ chế bảo mật; các biện pháp này chỉ phục vụ trải nghiệm người dùng.
- Mọi dữ liệu theo công ty, trạm, người dùng, vai trò, phòng ban, đơn vị hoặc phạm vi tương đương phải được backend đối chiếu với danh tính, trạng thái tài khoản và quyền hiện tại.
- Áp dụng nguyên tắc quyền tối thiểu: chỉ cấp quyền, mở endpoint, truy cập dữ liệu và cấp quyền database ở mức thực sự cần cho use case.
- Áp dụng bảo mật nhiều lớp; không phụ thuộc duy nhất vào token, route guard, mạng nội bộ, VPN, thiết bị công ty hoặc một cơ chế kiểm tra đơn lẻ.
- Khi danh tính, quyền, data scope hoặc trạng thái bảo mật thất bại, không xác định hay không thể xác minh, hệ thống phải từ chối an toàn thay vì mặc định cho phép.
- Không coi dữ liệu nội bộ là an toàn chỉ vì ứng dụng được sử dụng trong công ty.
- Thay đổi liên quan bảo mật phải được đánh giá trên backend, mobile, API contract, dữ liệu, logging, test và khả năng vận hành bị ảnh hưởng.
- Không làm giảm mức bảo mật hiện tại, bỏ kiểm tra hoặc mở quyền tạm chỉ để demo, build thành công hay hoàn thành nhanh một task.

## 19. Quản Lý Xác Thực Và Phiên

- Access token phải có thời hạn được cấu hình và phù hợp với rủi ro nghiệp vụ; không tạo token sống quá dài nếu không có cơ chế thu hồi hoặc vô hiệu hóa tương ứng.
- Backend phải kiểm tra chữ ký, issuer, audience, thời hạn, trạng thái tài khoản và trạng thái quyền hiện tại khi contract hoặc nghiệp vụ yêu cầu.
- Việc khóa tài khoản hoặc thay đổi quyền phải có hiệu lực theo yêu cầu nghiệp vụ; không được phụ thuộc vô thời hạn vào claim cũ trên thiết bị.
- Phân biệt `401 Unauthorized` cho phiên không hợp lệ hoặc chưa xác thực và `403 Forbidden` cho người đã xác thực nhưng không đủ quyền.
- Logout phải xóa state phiên, token và dữ liệu xác thực local; nếu backend hỗ trợ phiên có thể thu hồi thì phải gọi đúng contract để vô hiệu hóa phiên.
- Không lưu, truyền hoặc hiển thị token qua URL, query string, log, analytics, clipboard, screenshot, thông báo lỗi hoặc tài liệu; không log authorization header.
- Mobile phải lưu token nhạy cảm bằng secure storage phù hợp với nền tảng, không dùng vùng lưu plain text cho credential hoặc token.
- Không hardcode tài khoản, mật khẩu, token, OTP hoặc phiên Development trong source, fixture, screenshot hay tài liệu.
- Chỉ triển khai refresh token khi có yêu cầu và contract được xác nhận. Khi đã triển khai, phải đánh giá xoay vòng, thu hồi, phát hiện tái sử dụng bất thường, vô hiệu hóa từng phiên và toàn bộ phiên khi cần.
- Mọi thay đổi vòng đời token hoặc phiên phải được cập nhật đồng bộ ở backend, mobile, OpenAPI, tài liệu contract, test và hướng dẫn vận hành liên quan.
- Chi tiết triển khai riêng của backend và mobile tiếp tục tuân thủ `backend/AGENTS.md` và `mobile/AGENTS.md`; mục này không mặc định bắt buộc một cơ chế authentication mới.

## 20. Quản Lý Secret Và Cấu Hình Môi Trường

- Tách rõ Development, Staging và Production; không dùng chung secret giữa các môi trường.
- Không hardcode secret, credential, private key hoặc cấu hình production trong source code.
- Secret Development phải nằm ngoài repository bằng cơ chế secret cục bộ của nền tảng, biến môi trường hoặc giải pháp tương đương phù hợp.
- Production phải dùng cơ chế quản lý secret phù hợp với hạ tầng triển khai; không bắt buộc một sản phẩm cloud hoặc nhà cung cấp cụ thể.
- Mobile không được chứa JWT signing key, database credential, mật khẩu dịch vụ, API secret, payment secret, private key hoặc connection string.
- Mobile chỉ được chứa cấu hình công khai hoặc giá trị không gây rủi ro nếu bị trích xuất khỏi gói cài đặt.
- Không commit file môi trường có secret thật, cấu hình có mật khẩu, certificate private key, signing key, file credential hoặc backup chứa thông tin nhạy cảm.
- Việc một file được ignore không có nghĩa secret trong file đó an toàn nếu nó đã từng xuất hiện trong lịch sử Git, log, artifact hoặc nơi chia sẻ khác.
- Khi nghi ngờ secret đã bị lộ, phải coi secret là đã bị lộ, thực hiện rotate hoặc thu hồi và đánh giá lịch sử Git, log cùng các nơi secret có thể đã được sao chép; không chỉ xóa ở commit mới nhất.
- Cấu hình môi trường phải có guardrail để tránh backend Development trỏ nhầm Production hoặc `dangnhap.net`, mobile Development gọi nhầm API Production và test ghi dữ liệu vào database chuẩn.
- Không đưa URL nội bộ, tên server, credential, dữ liệu production hoặc thông tin hạ tầng nhạy cảm vào screenshot, mockup, fixture, log, tài liệu hoặc file `AGENTS.md`.

## 21. Logging, Audit Và Giám Sát

- Ưu tiên structured logging khi nền tảng hỗ trợ và dùng `traceId` hoặc `correlationId` để đối chiếu một luồng lỗi xuyên backend-mobile.
- Không log mật khẩu, password hash, access token, refresh token, OTP, secret, connection string, authorization header, private key hoặc payload xác thực nhạy cảm.
- Dữ liệu cá nhân và dữ liệu công ty nhạy cảm trong log phải được loại bỏ, che một phần, rút gọn hoặc thay bằng định danh nội bộ an toàn.
- Không log toàn bộ request hoặc response khi payload có thể chứa dữ liệu nhạy cảm.
- Không trả cho mobile production stack trace, SQL exception, inner exception, tên bảng, đường dẫn server, tên host hoặc chi tiết hạ tầng.
- Khi phân hệ hỗ trợ thao tác bảo mật, quản trị hoặc dữ liệu quan trọng, phải xác định nhu cầu audit riêng; audit log không được thay thế bằng log debug thông thường.
- Audit phù hợp nên xác định actor, hành động, thời điểm, đối tượng, kết quả, trace ID và nguồn request mà không ghi thừa dữ liệu nhạy cảm.
- Không ghi log quá mức gây lộ dữ liệu, giảm hiệu năng, tăng chi phí hoặc làm khó tìm sự kiện quan trọng.
- Mỗi môi trường phải có quy tắc lưu giữ, xoay vòng và dọn log phù hợp với nhu cầu vận hành.
- Log chạy thử, log điều tra và artifact tạm không phải source of truth và không được commit như tài liệu chính thức.

## 22. Quản Lý Dependency Và Supply Chain

- Không thêm package, SDK hoặc binary chỉ vì agent, AI hay ví dụ bên ngoài đề xuất.
- Trước khi thêm dependency phải đánh giá nhu cầu thực tế, khả năng dùng SDK hoặc package hiện có, trạng thái duy trì, phiên bản ổn định, giấy phép, hỗ trợ nền tảng, quyền nhạy cảm, rủi ro bảo mật và ảnh hưởng tới build hoặc vận hành.
- Ưu tiên dependency đang có nếu đáp ứng được yêu cầu; không dùng nhiều package giải quyết cùng một trách nhiệm nếu không có lý do rõ ràng.
- Không thêm dependency chỉ để giảm ít code nhưng làm tăng đáng kể rủi ro bảo trì, bảo mật hoặc triển khai.
- Package yêu cầu quyền hệ điều hành nhạy cảm chỉ được thêm khi feature thực sự cần và phạm vi quyền đã được đánh giá.
- Mọi thay đổi dependency phải cập nhật lockfile tương ứng khi nền tảng sử dụng lockfile.
- Không nâng version hàng loạt hoặc đổi dependency ngoài phạm vi task.
- Không tự thay state management, HTTP client, router, serializer, dependency injection framework hoặc hạ tầng tương đương khi chưa có nhu cầu được xác nhận.
- Không bỏ qua cảnh báo bảo mật dependency chỉ để build thành công.
- Khi phát hiện lỗ hổng nghiêm trọng, phải ghi rõ dependency, phiên bản, phạm vi sử dụng, mức ảnh hưởng, phương án cập nhật hoặc giảm thiểu và rủi ro breaking change.
- Không sử dụng package không rõ nguồn, binary không thể xác minh hoặc credential trong cấu hình package manager.

## 23. Bảo Mật Mạng, File Và Dữ Liệu Đầu Vào

- Môi trường Production chỉ giao tiếp qua HTTPS; không vô hiệu hóa kiểm tra chứng chỉ, bỏ qua TLS hoặc giữ cấu hình chấp nhận mọi chứng chỉ trong build production.
- Không gửi secret, credential hoặc token qua URL hay query string.
- Mọi dữ liệu từ mobile hoặc hệ thống ngoài phải được backend kiểm tra kiểu, định dạng, độ dài, khoảng giá trị, trạng thái, quan hệ, quyền và data scope phù hợp.
- Validation mobile chỉ phục vụ trải nghiệm người dùng và không thay thế validation backend.
- Không nối chuỗi SQL từ input và không dùng raw SQL không tham số hóa.
- Không tin `userId`, `stationId`, `companyId`, role, quyền, tổng tiền, trạng thái hoặc field readonly do client gửi lên; backend phải tự tính hoặc xác minh lại dữ liệu ảnh hưởng tới tiền, quyền, trạng thái, quan hệ nghiệp vụ và phạm vi dữ liệu.
- Nếu xuất hiện chức năng upload, phải kiểm tra kích thước, extension, MIME type, nội dung thực tế, tên file, số lượng và vị trí lưu; không tin tên file hoặc MIME type do client cung cấp.
- File upload phải có tên lưu an toàn, không nằm ở vị trí có thể thực thi và không làm lộ đường dẫn vật lý hoặc chi tiết hạ tầng storage cho mobile.
- Các quy tắc upload chỉ là guardrail khi feature xuất hiện, không phải yêu cầu tự triển khai upload hoặc storage mới.
- Chỉ thu thập, truyền và lưu dữ liệu thực sự cần cho use case.
- Dữ liệu nhạy cảm được cache hoặc lưu local phải có mục đích, thời hạn, cơ chế xóa, cơ chế invalidation và đánh giá rủi ro rõ ràng.

## 24. Kiểm Thử Bảo Mật Và Chất Lượng

Khi feature có liên quan, phạm vi kiểm tra tối thiểu phải bao gồm:

- Không có token, token hết hạn hoặc token không hợp lệ phải bị từ chối theo contract; token hợp lệ nhưng thiếu quyền phải trả `403`.
- Người dùng không được truy cập dữ liệu của công ty, trạm, người dùng hoặc phạm vi không được cấp.
- Client tự sửa định danh, role, function, quyền, trạng thái hoặc field scope không được vượt qua kiểm tra backend.
- Tài khoản bị khóa và thay đổi quyền phải có hiệu lực đúng contract và yêu cầu nghiệp vụ.
- Validation error phải nhất quán, gắn đúng field khi phù hợp và không lộ chi tiết nội bộ.
- Kiểm tra input rỗng, quá dài, sai kiểu, ngoài phạm vi, `null`, enum không hợp lệ, dữ liệu trùng, conflict và trạng thái không cho phép khi use case có liên quan.
- Với thao tác ghi, kiểm tra transaction, rollback, duplicate, concurrency và side effect của trigger hoặc database object khi có.
- Với upload, kiểm tra file quá lớn, sai loại, extension giả, tên nguy hiểm, upload lặp và file rỗng khi feature upload tồn tại.
- Không coi test UI là bằng chứng authorization backend đúng và không coi unit test dùng database giả là đủ cho hành vi phụ thuộc SQL Server.
- Khi không chạy được test bảo mật, integration hoặc E2E, phải nêu rõ phần chưa xác minh trong bàn giao.
- Không tắt test, bỏ assertion, nới điều kiện bảo mật hoặc sửa kỳ vọng sai chỉ để pipeline xanh.

## 25. Hiệu Năng Và Khả Năng Vận Hành

- Không tối ưu sớm khi chưa có bằng chứng, nhưng phải tránh lỗi hiệu năng rõ ràng và thiết kế không thể vận hành khi dữ liệu tăng.
- API danh sách có khả năng lớn phải cân nhắc phân trang, filter, search, sort ổn định và giới hạn page size.
- Không tải toàn bộ bảng, toàn bộ graph dữ liệu hoặc trường không cần thiết chỉ để hiển thị một phần; tránh N+1 query và truy vấn lặp không kiểm soát.
- Không gọi API trong vòng đời render hoặc rebuild không kiểm soát và không để một thao tác UI gửi request nhiều lần.
- Retry phải có giới hạn, có backoff khi phù hợp, không lặp vô hạn và không lặp thao tác ghi không idempotent theo cách gây trùng dữ liệu.
- Timeout và cancellation phải có giới hạn rõ ràng và được truyền qua các ranh giới phù hợp.
- Không cache dữ liệu nhạy cảm, dữ liệu phân quyền hoặc trạng thái tài khoản nếu không có expiration và invalidation phù hợp.
- Tối ưu hiệu năng không được làm sai authorization, data scope, tính nhất quán, transaction hoặc dữ liệu hiển thị.
- Khi thêm cache, background task, scheduled job, queue, batch processing hoặc cơ chế tương đương, phải xác định owner, vòng đời, retry, lỗi, idempotency, khả năng quan sát và cách dừng hoặc rollback.
- Không thêm hạ tầng phức tạp chỉ để chuẩn bị cho nhu cầu chưa tồn tại hoặc chưa được xác nhận.

## 26. Bảo Trì, Bảo Dưỡng Và Tính Tương Thích

- Thay đổi phải ưu tiên nhỏ, độc lập, có thể kiểm tra và dễ review; không refactor toàn bộ module khi task chỉ yêu cầu một use case nhỏ.
- Không tạo source of truth thứ hai cho cùng một logic; lịch sử code thuộc Git và việc tổ chức file tiếp tục tuân thủ mục 17.
- Breaking change phải được ghi rõ và cập nhật đồng bộ các consumer liên quan.
- Khi breaking change là cần thiết, phải xác định lý do, consumer bị ảnh hưởng, migration path, versioning khi cần, kế hoạch rollout và rollback.
- Không xóa hoặc đổi field API đang được sử dụng nếu chưa đánh giá tương thích ngược.
- Không để TODO kiến trúc, placeholder, mock vĩnh viễn hoặc hardcode che lỗi tồn tại như giải pháp lâu dài.
- Quyết định bền vững phải được thể hiện trong code, test, contract, `AGENTS.md` hoặc tài liệu repository phù hợp, không chỉ nằm trong lịch sử hội thoại.
- Chỉ cập nhật `AGENTS.md` cho cấu trúc, quy trình hoặc guardrail bền vững; không ghi chi tiết tạm thời của một task.
- Mỗi feature phải có đường đọc code rõ từ entry point tới contract, nghiệp vụ, data access, authorization, UI và test tương ứng.
- Không để file trung tâm trở thành nơi chứa nhiều module không liên quan; tách theo trách nhiệm, vòng đời thay đổi, khả năng kiểm thử và mức độ conflict, không theo giới hạn dòng máy móc.
- Không tạo abstraction dùng chung khi mới có một trường hợp sử dụng thực tế.
- Khi sửa bug phải cân nhắc regression test phù hợp; không sửa warning hoặc vấn đề ngoài phạm vi nếu chưa đánh giá ảnh hưởng.

## 27. Phối Hợp Nhiều Agent

- Trước khi sửa, mỗi agent phải có phạm vi rõ gồm phân hệ, thư mục, file, contract, database object và lệnh kiểm tra liên quan.
- Phạm vi ghi của các agent phải tách biệt khi có thể; không để hai agent cùng sửa một file trong cùng thời điểm nếu chưa có phân công và cơ chế tích hợp rõ.
- API contract, migration, lockfile, composition root và cấu hình dùng chung phải có một owner điều phối tại một thời điểm.
- Backend là source of truth của endpoint, request, response, validation, authorization, status code và error contract sau khi OpenAPI hoặc tài liệu contract được xác minh.
- Agent mobile không được tự sửa backend để làm UI chạy và agent backend không được tự sửa mobile để che breaking change, trừ khi task xuyên dự án giao rõ cả hai phạm vi.
- Khi API thay đổi, phải cập nhật đồng bộ backend, OpenAPI, tài liệu contract, DTO mobile, repository, state/controller, UI và test liên quan.
- Khi phát hiện vấn đề ngoài phạm vi, agent phải ghi nhận vị trí, bằng chứng, ảnh hưởng và đề xuất; không tự sửa lan sang module khác.
- Không dùng lịch sử hội thoại của agent khác làm source of truth thay cho code, test, contract hoặc tài liệu repository.
- Không ghi đè, reset, checkout đè hoặc hoàn tác thay đổi hợp lệ của agent khác khi chưa hiểu nguồn gốc và chưa được giao xử lý.
- Trước khi bàn giao, phải kiểm tra trạng thái thay đổi, diff thực tế, file ngoài phạm vi, file sinh tạm, log, conflict, lockfile và thay đổi cấu hình.
- Không dùng lệnh Git phá hủy thay đổi như `git reset --hard` hoặc tương đương khi chưa có yêu cầu rõ ràng và chưa đánh giá dữ liệu có thể mất.
- Agent chính chịu trách nhiệm cuối cùng về kiến trúc, contract, phạm vi, tích hợp và review kết quả của các agent hoặc subagent.
- Khi có mâu thuẫn hướng dẫn: yêu cầu trực tiếp của người dùng có ưu tiên cao nhất; file `AGENTS.md` gần mã nguồn hơn được ưu tiên cho chi tiết triển khai; hướng dẫn cấp dưới không được vi phạm mục tiêu, ranh giới hoặc nguyên tắc hệ thống của file tổng.

## 28. Quy Tắc Sử Dụng Subagent

- Chỉ sử dụng subagent khi task có thể chia thành phần độc lập với đầu vào, đầu ra, phạm vi file và tiêu chí hoàn thành rõ ràng.
- Không dùng subagent để thay thế trách nhiệm agent chính phải hiểu kiến trúc, contract hoặc rủi ro tích hợp.
- Agent chính phải xác định critical path trước khi giao việc; không giao một blocker trực tiếp nếu bước tiếp theo của agent chính phải chờ chính kết quả đó và không có lợi ích song song rõ ràng.
- Trước khi sửa code, subagent phải đọc `AGENTS.md` tổng, `AGENTS.md` gần mã nguồn, contract, test và source liên quan.
- Mỗi nhiệm vụ subagent phải nêu rõ thư mục hoặc file được phép sửa, file chỉ được đọc, module sở hữu, contract và database object liên quan, dependency được phép thay đổi cùng lệnh kiểm tra bắt buộc.
- Không giao hai subagent cùng sửa một file, một API contract, migration, composition root hoặc lockfile trong cùng thời điểm nếu chưa có cơ chế phối hợp rõ.
- Subagent không được tự mở rộng phạm vi, sửa warning không liên quan, refactor module khác, đổi kiến trúc chung, thêm dependency, đổi API contract hoặc sửa database nếu nhiệm vụ không cho phép rõ.
- Subagent mobile không được tự sửa backend để làm UI chạy và subagent backend không được tự sửa mobile để che lỗi contract.
- Khi phát hiện vấn đề ngoài phạm vi, subagent phải báo vị trí, bằng chứng, ảnh hưởng, mức độ và đề xuất; không tự sửa nếu chưa được giao.
- Subagent không được dựa vào hội thoại riêng làm source of truth; quyết định bền vững phải nằm trong code, test, contract, `AGENTS.md` hoặc tài liệu repository phù hợp.
- Không dùng placeholder, TODO, mock vĩnh viễn hoặc hardcode để báo nhiệm vụ hoàn thành.
- Trước khi bàn giao, subagent phải kiểm tra diff, xác nhận không sửa file ngoài phạm vi, chạy test hẹp nhất và lệnh build/analyze được giao khi môi trường hỗ trợ, xóa file tạm, làm sạch log và báo rõ phần chưa xác minh.
- Báo cáo subagent phải gồm mục tiêu, phạm vi, file đã đọc, file đã sửa, contract hoặc database object liên quan, dependency thay đổi, lệnh đã chạy, kết quả, giả định, vấn đề ngoài phạm vi và rủi ro xung đột.
- Agent chính phải review diff thực tế, test, contract và file ngoài phạm vi trước khi coi nhiệm vụ hoàn thành; không chấp nhận kết quả chỉ dựa trên phần tóm tắt của subagent.
- Subagent chỉ tạo commit riêng khi người dùng hoặc agent chính cho phép rõ; commit phải đúng phạm vi, message mô tả module và mục đích, không gộp cleanup không liên quan.
- Agent chính vẫn là người sở hữu quyết định cuối cùng và chịu trách nhiệm tích hợp kết quả.

## 29. Mẫu Giao Việc Cho Subagent

Mẫu dưới đây là hướng dẫn chung và không được chứa tên task, branch hoặc file tạm thời của một phiên cụ thể:

```text
### Mẫu Giao Việc Cho Subagent

**Mục tiêu**
- Mô tả một kết quả cụ thể cần hoàn thành.

**Phạm vi được phép sửa**
- Liệt kê chính xác thư mục hoặc file.

**Chỉ được đọc, không sửa**
- Liệt kê source, contract hoặc tài liệu liên quan.

**Không được làm**
- Không sửa ngoài phạm vi.
- Không đổi API contract hoặc dependency nếu chưa được giao.
- Không refactor kiến trúc chung hoặc sửa phía backend/mobile còn lại.
- Không sửa database, migration hoặc cấu hình chung nếu không thuộc nhiệm vụ.

**Nguồn sự thật**
- `AGENTS.md` tổng và `AGENTS.md` gần mã nguồn.
- API contract/OpenAPI, code, test và yêu cầu trực tiếp của task.

**Tiêu chí hoàn thành**
- Logic đúng, không placeholder hoặc hardcode che lỗi.
- Test liên quan đạt hoặc phần chưa chạy được báo rõ.
- Không có file ngoài phạm vi bị thay đổi.
- Có báo cáo bàn giao đầy đủ.

**Lệnh kiểm tra**
- Liệt kê chính xác lệnh phải chạy.

**Đầu ra bàn giao**
- File đã sửa và tóm tắt thay đổi.
- Test/lệnh đã chạy cùng kết quả.
- Phần chưa xác minh và giả định còn lại.
- Vấn đề ngoài phạm vi và rủi ro xung đột.
```
