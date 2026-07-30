# TTsmart Mobile

> Tài liệu bàn giao riêng cho ứng dụng Flutter trong thư mục `mobile/` của
> repository `TTSmartApp`. Nội dung được rà theo source hiện tại ngày
> `2026-07-30`; không mô tả phần triển khai backend hoặc database.

## 1. Tóm tắt trạng thái

Ứng dụng hiện có một vertical slice tương đối đầy đủ cho xác thực, App Shell,
RBAC/quản trị tài khoản và quản lý công ty. Các màn hình Trang chủ, Đơn hàng,
Báo cáo và Thông báo đã có UI và controller để kiểm tra luồng mobile, nhưng vẫn
đang dùng repository mock/in-memory trong composition root.

| Phần | Trạng thái hiện tại |
| --- | --- |
| Đăng nhập, khôi phục phiên, đăng xuất, đổi mật khẩu | **Đã nối API thật** |
| App Shell, 4 tab, header, route theo quyền | **Đã làm**; cần kiểm tra runtime với phiên thật |
| Người dùng / Vai trò / Function | **Đã nối API thật** |
| Quản lý công ty | **Đã nối API thật**; function code hiện dùng là `QLCT`, cần xác nhận lại với backend |
| Trang chủ | **UI hoàn chỉnh, dữ liệu mock** |
| Đơn hàng | **UI hoàn chỉnh, dữ liệu mock** |
| Báo cáo | **UI hoàn chỉnh, dữ liệu mock** |
| Thông báo | **Empty state, repository mock trả danh sách rỗng** |
| Cài đặt | **UI làm xong; tùy chọn thông báo chỉ lưu trong memory** |
| Cấp phối, Cân ô tô, Quản lý xe, Camera, Vật liệu, Trạm | **Màn preview, chưa có nghiệp vụ/API** |
| Runtime với backend Development, emulator/thiết bị thật | **Chưa xác minh end-to-end** |
| Release signing và build phát hành | **Chưa cấu hình/xác minh** |

### Kết luận ngắn

- Không coi số liệu trên Trang chủ, Đơn hàng hoặc Báo cáo là dữ liệu thật.
- Không coi các key `preview.*` là function code backend.
- Không dùng bộ lọc phạm vi mock hiện tại làm cơ chế authorization.
- Trước khi production phải thay repository mock bằng API thật và xác nhận lại
  contract, function code, phạm vi tenant/trạm với backend.

## 2. Mục tiêu và phạm vi mobile

- Ứng dụng nội bộ TTsmart cho người dùng quản lý tập trung nhiều công ty/trạm.
- Luồng chuẩn là Flutter gọi REST API qua `http`; mobile không kết nối trực tiếp
  SQL Server và không chứa connection string, secret hoặc credential.
- App Shell cố định bốn tab: `Trang chủ`, `Đơn hàng`, `Báo cáo`, `Xem thêm`.
- Phạm vi dữ liệu dài hạn phải do backend cấp và kiểm tra authorization; client
  chỉ hiển thị lựa chọn được backend trả về.
- Chế độ một trạm tự quản lý, offline mode, background sync và các luồng nghiệp
  vụ chưa được xác nhận **không nằm trong phiên bản hiện tại**.

## 3. Công nghệ và cấu trúc

- Flutter `3.44.7` stable trên máy phát triển hiện tại.
- Dart SDK `3.12.2`; `pubspec.yaml` yêu cầu `sdk: ^3.12.2`.
- Android package: `com.ttsmart.mobile`.
- iOS bundle identifier hiện tại: `com.ttsmart.mobile`.
- Nền tảng source hiện có: Android và iOS; chưa có thư mục `web`, `windows`,
  `linux` hoặc `macos`.
- State management: `ChangeNotifier`.
- HTTP/API: package `http`, API client dùng chung trong `lib/core/network/`.
- Lưu token: `flutter_secure_storage`.
- Chọn logo công ty: `image_picker`.
- Serialization: mapping JSON thủ công, không dùng code generation.
- Dependency wiring thủ công tại `lib/main.dart`, `lib/app.dart` và
  `AppFeatureRepositories`.
- Điều hướng hiện dùng `MaterialPageRoute`, chưa dùng router/deep link framework.
- UI dùng Material, responsive bằng `LayoutBuilder` và các widget dùng chung.
- Chuỗi giao diện hiện viết trực tiếp bằng tiếng Việt; chưa có hệ thống
  localization.

### Cây source chính

```text
mobile/
  lib/
    main.dart                         # composition root
    app.dart                          # app root, theme, session screen
    app_dependencies.dart             # repository abstractions wiring
    core/
      config/                         # API_BASE_URL, timeout
      models/                         # data scope, time range
      network/                        # ApiClient, ProblemDetails, errors
      storage/                        # secure token storage
      theme/                          # Material theme
      utils/                          # date/time display
      widgets/                        # empty/error/content/common widgets
    features/
      auth/                            # login, session, account, password
      shell/                           # App Shell, menu registry, route guard
      access_management/               # users, roles, functions, RBAC matrix
      company_management/              # company CRUD and logo
      home/                            # dashboard UI, currently mock
      orders/                          # orders UI, currently mock
      reports/                         # report UI, currently mock
      notifications/                   # notification UI, currently mock
      settings/                        # settings UI, memory repository
      more/                            # preview modules and system menu
  test/                                # model, client, repository, controller, widget tests
  docs/                                # contract proposals and mobile notes
  assets/images/ttsmart_logo.png       # logo asset
```

Mỗi feature giữ `data/models`, `data/repositories` và
`presentation/controllers/screens/widgets` khi cần. Widget không gọi HTTP và
controller không tự xây URL; repository là ranh giới gọi API/chuyển đổi response.

## 4. Các nghiệp vụ đã làm

### 4.1. Xác thực và phiên đăng nhập — API thật

Đường đi chính:

1. Mở app vào `SplashScreen`.
2. Đọc access token và thời hạn từ secure storage.
3. Nếu token còn hạn, gọi `GET /api/auth/me` để khôi phục phiên.
4. Nếu chưa có phiên, hiển thị `LoginScreen`.
5. Nếu không xác minh được phiên, hiển thị `SessionRecoveryScreen` với lựa chọn
   thử lại hoặc xóa phiên local.
6. Khi đăng nhập thành công, lưu token và mở `AppShell`.

Đã có:

- `POST /api/auth/login`.
- `GET /api/auth/me`.
- `POST /api/auth/change-password`.
- `POST /api/auth/logout`.
- Hiển thị thông tin tài khoản hiện tại.
- Đổi mật khẩu với validation phía client và field error từ backend.
- Xóa token local khi logout, kể cả khi API logout lỗi.
- Token lưu bằng `flutter_secure_storage`, không dùng preferences plain text.
- `401` từ API bảo vệ gọi callback xóa phiên và đưa app về Login.
- `403` được hiển thị là không có quyền, không tự đăng xuất.

Chưa có:

- Refresh token vì chưa có contract tương ứng trong mobile.
- Chỉnh sửa hồ sơ tài khoản/avatar từ màn `AccountScreen`.
- Xác minh login và logout với backend thật trên thiết bị.

### 4.2. App Shell và phân quyền

- `IndexedStack` giữ state, vị trí cuộn, search và filter khi đổi bốn tab.
- Header có avatar tài khoản, thông báo và cài đặt.
- Avatar mở thông tin tài khoản; không dùng avatar thay cho menu nghiệp vụ.
- Module hệ thống nằm trong `features/shell/` và chỉ mở khi phiên có quyền
  `dSach` trên function code tương ứng.
- Route kiểm tra quyền lại khi mở, không chỉ dựa vào menu đã hiển thị.
- Function code không dựa trên tên role.
- Menu `Người dùng`, `Phân quyền`, `Chức năng` dùng các code `QLND`, `QLQ`, `QLCN`.
- Menu `Quản lý công ty` hiện dùng code `QLCT`; cần backend xác nhận mapping trước
  khi coi là contract đã khóa.

### 4.3. Quản lý người dùng — API thật

Function code: `QLND`.

Đã có:

- Danh sách phân trang.
- Tìm kiếm.
- Lọc trạng thái và role.
- Xem chi tiết.
- Tạo người dùng.
- Cập nhật thông tin người dùng.
- Gán hoặc thay đổi danh sách role bằng `roleIds` số nguyên.
- Kích hoạt/khóa tài khoản bằng payload `isActive`.
- Reset mật khẩu.
- Xóa người dùng có xác nhận.
- Kiểm tra quyền `view`, `create`, `update`, `delete` ở các màn liên quan.
- Giữ người dùng hiện tại không bị khóa theo quy tắc UI hiện có.

Endpoint repository:

```text
GET    /api/users
GET    /api/users/{id}
POST   /api/users
PUT    /api/users/{id}
PUT    /api/users/{id}/status
PUT    /api/users/{id}/roles
POST   /api/users/{id}/reset-password
DELETE /api/users/{id}
```

### 4.4. Quản lý vai trò và ma trận quyền — API thật

Function code: `QLQ`.

Đã có:

- Danh sách vai trò phân trang.
- Tìm kiếm và lọc trạng thái.
- Xem chi tiết.
- Tạo, sửa, kích hoạt/ngừng và xóa vai trò.
- Lấy toàn bộ role theo nhiều trang để phục vụ form gán role cho user.
- Xem ma trận function của role.
- Bật/tắt function trong ma trận.
- Bật/tắt `Đầy đủ` và chỉnh từng quyền.
- Gửi payload bằng `functionId` số nguyên và `activeKey`, không gửi contract cũ
  `right` hoặc `possibleRight`.
- Sau khi lưu ma trận, app gọi lại `GET /api/auth/me` để đồng bộ quyền phiên.

Endpoint repository:

```text
GET    /api/roles
GET    /api/roles/{id}
POST   /api/roles
PUT    /api/roles/{id}
PUT    /api/roles/{id}/status
GET    /api/roles/{id}/function-matrix
PUT    /api/roles/{id}/functions
PUT    /api/roles/{id}/functions/{functionId}/active-key
DELETE /api/roles/{id}/functions/{functionId}
DELETE /api/roles/{id}
```

### 4.5. Quản lý function/menu — API thật

Function code: `QLCN`.

Đã có:

- Danh sách cây function.
- Tìm kiếm và lọc trạng thái.
- Xem chi tiết function.
- Tạo function với function cha, mã, tên, URL, ghi chú, thứ tự và icon.
- Cập nhật function.
- Kích hoạt/ngừng function.
- Xóa function có xác nhận.

Endpoint repository:

```text
GET    /api/functions
GET    /api/functions/tree
GET    /api/functions/{id}
POST   /api/functions
PUT    /api/functions/{id}
PUT    /api/functions/{id}/status
DELETE /api/functions/{id}
```

### 4.6. Quản lý công ty — API thật

Function code trong mobile: `QLCT`. Mapping này chưa được ghi nhận trong báo cáo
contract cũ, vì vậy cần xác nhận lại từ phiên backend trước khi phát hành.

Đã có:

- Danh sách phân trang.
- Tìm kiếm.
- Lọc trạng thái `1` đang hoạt động hoặc `99` đã xóa.
- Lọc công ty đang khóa/không khóa.
- Tải thêm trang và chống trùng ID.
- Xem chi tiết.
- Tạo và sửa thông tin công ty.
- Gói sử dụng `Miễn phí`/`Trả phí`.
- Cập nhật số người dùng, thông tin liên hệ và ghi chú.
- Khóa/mở khóa công ty.
- Cập nhật ngày hết hạn.
- Chọn và upload logo qua multipart.
- Tải logo từ API.
- Xóa mềm và khôi phục công ty.
- Permission gate cho xem/tạo/sửa/xóa ở màn danh sách và chi tiết.

Endpoint repository:

```text
GET    /api/companies
GET    /api/companies/{id}
POST   /api/companies
PUT    /api/companies/{id}
PUT    /api/companies/{id}/lock
PUT    /api/companies/{id}/expiration
POST   /api/companies/{id}/logo       # multipart field: file
GET    /api/companies/{id}/logo
DELETE /api/companies/{id}
POST   /api/companies/{id}/restore
```

## 5. Các màn hình đã làm nhưng còn mock

### 5.1. Trang chủ

File chính: `lib/features/home/`.

UI/controller hiện có:

- Chọn phạm vi `Toàn công ty`, `Trạm Tân Phú`, `Trạm Bình Chánh`.
- Chọn kỳ `Hôm nay`, `7 ngày`, `Tháng này`.
- Card tổng quan đơn hàng, mác bê tông, xe trộn và nhân viên có đơn.
- Biểu đồ sản lượng tùy theo kỳ.
- Danh sách trạng thái trạm.
- Hoạt động gần đây.
- Loading, empty/error và refresh theo controller.

Repository hiện tại là `MockHomeRepository`. Số liệu được tạo trong code bằng hệ
số minh họa, không phải dữ liệu backend. Contract đề xuất nằm trong
`docs/mobile-ui-backend-contract-proposal.md` với endpoint dự kiến
`GET /api/dashboard/summary`.

### 5.2. Đơn hàng

File chính: `lib/features/orders/`.

UI/controller hiện có:

- Tìm theo mã đơn, khách hàng hoặc mác bê tông.
- Debounce tìm kiếm `350ms`.
- Lọc phạm vi, kỳ thời gian và trạng thái.
- Trạng thái mock: `Chờ xử lý`, `Đang trộn`, `Đang giao`, `Hoàn thành`, `Đã hủy`.
- Danh sách card responsive.
- Màn chi tiết với giao hàng, khối lượng, đã giao, địa điểm, độ sụt, hình thức
  bơm, liên hệ và ghi chú.
- Loading, empty, lỗi và xóa bộ lọc.

Repository là `MockOrdersRepository`. Chưa có phân trang server, create/update/
delete, và mock hiện **không thực sự lọc theo `timeRange`** dù model/controller
đã có trường này. Dữ liệu chi tiết có marker `Dữ liệu minh họa` để tránh nhầm là
dữ liệu thật. Contract đề xuất gồm `GET /api/orders` và `GET /api/orders/{id}`.

### 5.3. Báo cáo

File chính: `lib/features/reports/`.

UI/controller hiện có:

- Chọn phạm vi và kỳ thời gian.
- Card tổng đơn, sản lượng, tỷ lệ hoàn thành và số trạm hoạt động.
- Biểu đồ xu hướng.
- So sánh theo từng trạm.
- Responsive layout và các trạng thái loading/error/empty.

Repository là `MockReportsRepository`; số liệu được tính từ hằng số minh họa.
Chưa có export/in hoặc API thật. Contract đề xuất: `GET
/api/reports/order-summary`.

### 5.4. Thông báo

File chính: `lib/features/notifications/`.

- Có model loại thông báo, title, message, thời gian và read state.
- Có refresh, loading, retry và empty state.
- `MockNotificationsRepository` luôn trả danh sách rỗng.
- Chưa có API list, unread count thật, đánh dấu đã đọc/chưa đọc, push
  notification hoặc permission hệ điều hành.
- Contract đề xuất: `GET /api/notifications` trả danh sách phân trang và
  `unreadCount`.

### 5.5. Cài đặt

File chính: `lib/features/settings/`.

- Bật/tắt `Nhận thông báo`.
- Mở thông tin tài khoản.
- Mở đổi mật khẩu.
- Đăng xuất có xác nhận.
- Hiển thị version `1.0.0`.

`MemorySettingsRepository` chỉ giữ trạng thái trong process; đóng/mở app sẽ mất
tùy chọn. Chưa có persistent settings, system notification permission hoặc
API lưu cài đặt theo tài khoản/thiết bị.

## 6. Module preview chưa triển khai

Các module dưới đây đang được đăng ký trong
`lib/features/more/presentation/more_module_registry.dart` và chỉ mở
`ModulePreviewScreen`:

- `preview.mix-design`: Cấp phối.
- `preview.vehicle-scale`: Cân ô tô.
- `preview.fleet`: Quản lý xe.
- `preview.camera`: Camera.
- `preview.materials`: Vật liệu.
- `preview.stations`: Trạm.

Các key này là key tạm của FE, **không phải function code backend**. Trước khi
nối từng module cần xác nhận tên nghiệp vụ, endpoint, DTO, phạm vi dữ liệu,
function code, `ActiveKey`, route và quyền. Không được dùng preview để hiển thị
dữ liệu nhạy cảm hoặc coi là đã hoàn thành nghiệp vụ.

## 7. Contract mobile đang dùng

### Quy tắc JSON và response

- Tên field mặc định `camelCase`.
- ID resource hiện là số nguyên.
- Response phân trang dùng các field `items`, `pageNumber`, `pageSize`,
  `totalCount`, `totalPages`.
- Trạng thái truy vấn dữ liệu dùng `status=1` hoặc `status=99` ở các repository
  đã xác nhận.
- Payload trạng thái dùng `isActive`.
- Gán role dùng `roleIds` là danh sách số nguyên.
- Gán quyền dùng `functions[].functionId` và `activeKey`.
- Timestamp parse theo ISO 8601/UTC và chỉ đổi sang local ở lớp hiển thị.
- Ngày hết hạn của công ty được gửi dạng ngày, không tự áp timezone.
- Lỗi ưu tiên `ProblemDetails`; field errors được ánh xạ về đúng field khi có.
- `400`, `401`, `403`, `404`, `409`, `5xx` được chuyển thành `ApiException`.

### ActiveKey

`PermissionSet` là source of truth phía mobile cho mapping quyền. `ActiveKey`
phải có đúng 9 ký tự theo thứ tự:

```text
0 view | 1 create | 2 update | 3 delete | 4 import
5 export | 6 print | 7 other | 8 dSach
```

- `000000000` là không có quyền.
- `111111111` là đầy đủ 9 quyền.
- `full` là trạng thái tổng hợp, không phải ký tự thứ 10.
- ActiveKey sai độ dài/format được coi là không có quyền.
- Function cha vẫn giữ trong cây khi có function con được cấp quyền.

### Phạm vi tenant/trạm

Hiện model dùng chung `DataScopeOption` để thiết kế UI, nhưng các scope đang là
giá trị mock cục bộ. Mobile chưa có endpoint context thật. Contract đề xuất
`GET /api/mobile/context` để backend trả tenant, quyền và các phạm vi công
ty/trạm được phép; mọi endpoint vẫn phải tự authorization ở backend.

Không được coi `companyId`, `stationId` hoặc filter người dùng chọn trên mobile
là bằng chứng authorization. Khi nối API thật phải kiểm tra cả truy cập chéo
công ty/trạm và trường hợp backend từ chối phạm vi.

## 8. Cấu hình và chạy trên máy mới

### Yêu cầu

- Flutter stable có Dart SDK tối thiểu tương thích `^3.12.2`.
- Android Studio/Android SDK và một emulator hoặc thiết bị Android nếu chạy
  Android.
- macOS + Xcode nếu chạy iOS; iOS project đặt deployment target `13.0`.
- Backend Development phải chạy và thiết bị/emulator phải truy cập được API.
- Không cần sao chép `.dart_tool/`, `build/`, `coverage/` hoặc cache local.

Máy hiện tại đã chạy Flutter `3.44.7` stable, revision
`84fc5cbb223bc12f83d65b647ff8a56caf779ffd`, Dart `3.12.2`. Không bắt buộc phải
giữ nguyên đường dẫn `C:\Users\TTSmart\dev\flutter`; chỉ cần SDK tương thích.

### Các bước cài đặt

```powershell
cd <workspace>\TTSmartApp\mobile
flutter doctor -v
flutter pub get
flutter devices
```

Nếu `flutter` chưa có trong `PATH`, dùng đường dẫn đầy đủ tới
`flutter.bat`. Không chạy `flutter pub upgrade` hàng loạt; `pubspec.lock` đã
được commit và nên được giữ ổn định khi đổi máy.

### Chạy Android Emulator

```powershell
flutter run -d <device-id> `
  --dart-define=API_BASE_URL=http://10.0.2.2:5052
```

`10.0.2.2` là địa chỉ host từ Android Emulator. Với thiết bị thật, thay bằng
IP LAN của máy backend và bảo đảm backend bind ra interface mà thiết bị truy cập
được. Không đưa URL production, token, mật khẩu hoặc secret vào source.

`API_BASE_URL` có default `http://10.0.2.2:5052` trong
`lib/core/config/app_config.dart`, timeout request là `30 giây`, và giá trị được
validate phải là URL `http` hoặc `https`. Android chỉ bật cleartext trong debug
manifest; môi trường staging/production nên dùng HTTPS.

### Chạy iOS

```powershell
flutter run -d <ios-device-or-simulator> `
  --dart-define=API_BASE_URL=https://<development-api-host>
```

Lệnh iOS thực tế cần chạy trên macOS/Xcode. `Info.plist` đã có
`NSPhotoLibraryUsageDescription` cho luồng chọn logo công ty. Chưa có xác minh
runtime iOS trong snapshot này.

### Package và asset chính

- `http`: REST JSON và multipart.
- `flutter_secure_storage`: access token/thời hạn phiên.
- `image_picker`: chọn ảnh logo công ty.
- `http_parser`: content type cho multipart.
- `flutter_lints`: lint/analyzer.
- `assets/images/ttsmart_logo.png`: logo hiển thị trong app.

## 9. Kiểm tra và chất lượng hiện tại

### Lệnh nên chạy trên máy mới

```powershell
dart format lib test
flutter analyze
flutter test
```

Khi chỉ kiểm tra logic/API có thể chạy test theo nhóm:

```powershell
flutter test test/core/network
flutter test test/features/auth
flutter test test/features/access_management
flutter test test/features/company_management
flutter test test/features/home
flutter test test/features/orders
```

### Snapshot xác minh ngày `2026-07-30`

- `dart analyze`: **PASS**, kết quả `No issues found!`.
- `dart format --output=none --set-exit-if-changed lib test`: formatter hiện tại
  báo `app_header.dart` cần format và trả exit code `1`; cần xem lại khi tiếp
  tục làm việc, không nên tự mở rộng phạm vi sửa trong task bàn giao này.
- `flutter test --no-pub --concurrency=1`: **timeout sau 300 giây**, không có
  kết quả pass/fail cuối cùng; sau timeout không còn tiến trình Dart/Flutter chạy.
- `flutter analyze`, login thật, backend response thật, 401/403/409 end-to-end,
  emulator, thiết bị thật, layout thật và APK release: **chưa xác minh**.

### Test hiện có

- `test/widget_test.dart`: màn Login khi chưa có token.
- `test/app_session_navigation_test.dart`: xóa route bảo vệ khi phiên chuyển
  sang unauthenticated.
- `test/core/network/api_client_test.dart`: JSON, Bearer token, ProblemDetails,
  401 callback và multipart.
- `test/features/auth/`: parse session/role/function/ActiveKey và logout.
- `test/features/access_management/`: model contract, status, roleIds,
  function matrix, endpoint và delete.
- `test/features/company_management/`: model, request payload, pagination,
  expiration date, repository, controller và company widget.
- `test/features/home/`: đổi phạm vi và kỳ thời gian.
- `test/features/orders/`: debounce tìm kiếm.

Chưa có integration test với backend thật, test route đầy đủ theo từng function,
test phạm vi chéo trạm hoặc test runtime trên Android/iOS.

## 10. Việc chưa làm và thứ tự tiếp tục

### Ưu tiên P0 — cần làm trước khi coi app dùng dữ liệu thật

1. Xác nhận API Development và chạy login thật trên emulator/thiết bị.
2. Chốt contract context tenant/phạm vi trạm và thay scope mock trong Home,
   Orders, Reports bằng dữ liệu backend.
3. Thay `MockHomeRepository` bằng API dashboard thật.
4. Thay `MockOrdersRepository` bằng API đơn hàng thật, gồm phân trang ổn định,
   enum trạng thái, timezone và quy tắc khối lượng.
5. Thay `MockReportsRepository` bằng API báo cáo thật, gồm kỳ báo cáo, timezone,
   công thức và so sánh trạm.
6. Xác nhận function code `QLCT` và permission matrix cho quản lý công ty.
7. Kiểm tra `401`, `403`, `404`, `409`, validation field error và từ chối truy
   cập chéo company/station với backend.

### Ưu tiên P1 — hoàn thiện các module đã có UI

- Nối `NotificationsRepository` với API list, unread count và mark-as-read.
- Quyết định settings thông báo lưu theo tài khoản, thiết bị hay cả hai; thay
  `MemorySettingsRepository` bằng persistence/API phù hợp.
- Bổ sung create/edit/delete hoặc xác nhận rõ đơn hàng chỉ read-only ở phiên đầu.
- Xác nhận các công thức dashboard/report và dữ liệu “hoạt động gần đây”.
- Thêm route/function mapping thật cho các module preview trước khi mở dữ liệu.
- Chạy full test và runtime trên Android; kiểm tra iOS nếu cần phát hành iOS.

### Ưu tiên P2 — phát hành và bảo trì

- Cấu hình signing, application ID/bundle ID theo môi trường phát hành và build
  release.
- Không dùng HTTP cleartext ngoài debug; tách Development/Staging/Production.
- Thêm localization nếu cần hỗ trợ nhiều ngôn ngữ.
- Thêm integration test và kiểm tra accessibility/runtime layout.
- Đổi version hiển thị trong Settings sang nguồn version duy nhất thay vì text
  hardcode `1.0.0`.
- Chỉ thêm refresh token, offline/cache, push notification hoặc background sync
  sau khi contract và nhu cầu được xác nhận.

## 11. Tài liệu liên quan trong mobile

- `AGENTS.md`: quy tắc riêng của mobile.
- `FRONTEND_ISSUES.md`: báo cáo kiểm tra frontend trước đây, cập nhật ngày
  `2026-07-24`; hữu ích để đối chiếu nhưng không thay thế source hiện tại.
- `docs/mobile-ui-backend-contract-proposal.md`: đề xuất contract cho dashboard,
  orders, reports, notifications, settings và context; các endpoint mới trong
  file này chưa được coi là API đã triển khai.
- `skills/flutter-business-module/`: checklist khảo sát và bàn giao module.
- `skills/flutter-mobile-crud/`: checklist CRUD/API/UI cho các màn dữ liệu.

## 12. Checklist bàn giao sang máy khác

- [ ] Lấy đúng repository/branch và vào thư mục `mobile/`.
- [ ] Cài Flutter stable tương thích Dart `3.12.2` và chạy `flutter doctor -v`.
- [ ] Chạy `flutter pub get`, không xóa hoặc upgrade lockfile ngoài phạm vi.
- [ ] Chọn thiết bị bằng `flutter devices`.
- [ ] Truyền `API_BASE_URL` đúng môi trường; Android Emulator dùng
      `10.0.2.2`, thiết bị thật dùng địa chỉ host có thể truy cập.
- [ ] Không copy token, password, secret, `.dart_tool/`, `build/` hoặc
      `coverage/` giữa các máy.
- [ ] Chạy `dart analyze`; sau đó thử các test nhóm nếu Flutter test không treo.
- [ ] Chạy runtime với backend Development để xác minh Login, menu quyền,
      quản trị user/role/function và quản lý công ty.
- [ ] Ghi lại mọi thay đổi contract vào DTO, repository, test và tài liệu.
- [ ] Trước khi commit, kiểm tra `git status`, diff và chắc chắn task này chỉ
      thay đổi `mobile/README.md` nếu không có yêu cầu khác.

### Trạng thái lúc tạo tài liệu này

Branch hiện tại là `main`. README này là thay đổi bàn giao chưa commit; không có
ý định commit thay người dùng. Sau khi chuyển máy, nên commit README cùng các
thay đổi tiếp theo của mobile để giữ tài liệu và source đồng bộ.
