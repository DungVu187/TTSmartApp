# Đồng bộ UI/UX mobile với Figma — 29/09/2026

## Phạm vi và mốc xuất phát

- Nhánh: `feat/mobile-figma-redesign`; mốc trước khi làm: `19dae62`.
- Thiết kế: Figma `TTsmart Mobile Redesign` (`Legji6zB1I6pi1DLMoPZKF`), bản Sáng/Tối. Các màn bộ lọc đã được đo ở 390px; 360px, 412px, chữ phóng lớn và tương tác prototype mới chưa được xác minh.
- Chỉ sửa Flutter mobile theo bốn phần dưới đây. Giữ logic API và màn rộng hiện có. Không đưa `android/build/`, `publish*/` hoặc thay đổi ngoài phần đang làm vào commit.
- Sau **mỗi phần**: chạy kiểm tra liên quan, cập nhật checkpoint ngay trong tài liệu này và `C:\Users\TTSmart\.claude\projects\D--TTSmartApp\ui-redesign-progress.md`, commit đúng file của phần đó, rồi push `origin/feat/mobile-figma-redesign`. Nếu kiểm tra hoặc push lỗi, ghi trạng thái thật và xử lý trước phần sau.

## Phần 1 — Điều hướng dưới và Xem thêm

**Thay đổi:** Menu dưới là `Trang chủ · Đơn hàng · Thống kê · Cấp phối · Xem thêm`; tab Hệ thống cũ ra khỏi menu. Cấp phối mở như màn gốc của tab, không có nút quay lại. Sheet Xem thêm chia `Vận hành` (Cân ô tô, Vật liệu), `Tổ chức` (Công ty, Trạm), `Hệ thống` (Chức năng, Phân quyền, Người dùng). Ba mục Hệ thống đi thẳng tới màn tương ứng; S01 không còn là điểm vào. Giữ điều kiện hiện tab/mục theo quyền và dựng tab khi truy cập lần đầu.

**Code hiện có:** `app_shell.dart` vẫn dùng tab Hệ thống; `more_screen.dart` vẫn gộp Tổ chức & Hệ thống và đặt Cấp phối trong Vận hành.

**Hoàn tất khi:** thứ tự/biểu tượng/chọn tab đúng ở tài khoản có quyền và thiếu quyền; Xem thêm dẫn đúng màn; tab Cấp phối không có nút Back; test shell và phân quyền liên quan đạt, `flutter analyze` không có lỗi mới.

**Checkpoint:** `Hoàn tất và đã push` — `899d863` (`origin/feat/mobile-figma-redesign`). Test shell `2/2`, mở S02 từ Xem thêm `1/1`; ảnh Xem thêm đã soát và cập nhật golden local `1/1`. `git diff --cached --check` đạt. `flutter analyze --no-pub` chỉ còn 1 `info` cũ ở `notifications_controller_test.dart` (`fake_async` chưa khai báo), không có error/warning mới. Route mở module trực tiếp được bổ sung `AppScope` sau khi test phát hiện lỗi thật. Chưa chạy full suite cho phần này.

## Phần 2 — Bộ chọn ngày giờ C15

**Thay đổi:** Lịch chung giữ đúng 6 hàng, ô ngày ngoài tháng để trống; tiêu đề tháng/năm bấm được, mở bảng 12 tháng và bảng 12 năm/trang, vẫn giữ mũi tên đổi tháng. Ô Từ/Đến đang chỉnh có trạng thái nổi bật và tự chuyển sang Đến sau khi chọn Từ. Hàng giờ/phút mang nhãn `Giờ bắt đầu` hoặc `Giờ kết thúc`. Bộ chọn **khoảng thời gian** không cho ngày/giờ tương lai, kể cả khi chọn hôm nay; các lựa chọn tương lai mờ và vô hiệu. Bộ chọn **một ngày** dùng cùng lịch/tháng/năm, nhưng vẫn cho ngày tương lai ở Hạn sử dụng công ty.

**Code hiện có:** `app_date_picker.dart` đã có ô Từ/Đến và hàng giờ, nhưng lịch dùng số tuần biến thiên, tháng/năm chưa bấm chọn, khoảng thời gian mặc định cho tới 20 năm sau và giờ chưa bị giới hạn theo hiện tại. Chỉ bổ sung phần thiếu, giữ API và key đang dùng.

**Hoàn tất khi:** đổi giữa tháng 5/6 tuần không đổi chiều cao; chọn tháng/năm đi tới tháng đúng; không thể chọn ngày/giờ sau `now` trong khoảng thời gian; Hạn sử dụng vẫn chọn được tương lai; test widget biên thời gian và `flutter analyze` đạt.

**Checkpoint:** `Hoàn tất và đã push` — `932ea97` (`origin/feat/mobile-figma-redesign`). Lịch C15 cố định 6 tuần, chọn tháng/năm, khóa ngày/giờ tương lai trong khoảng thời gian, giữ Hạn sử dụng chọn tương lai. Targeted widget tests `21/21`; visual C15 Sáng/Tối `2/2`, ảnh đã soát. `flutter analyze --no-pub` chỉ còn 1 `info` cũ về `fake_async`; `git diff --cached --check` đạt. Chưa chạy full suite.

## Phần 3 — Bộ lọc luôn nhìn thấy trên mobile

**Thay đổi:** Bỏ hàng chip phải kéo ngang ở các màn liên quan, tận dụng `FilterChipButton` hiện có, không thêm dependency. Đơn hàng: hàng 1 `Công ty · Trạm`, hàng 2 `Thời gian · Nhân viên`. Trang chủ, Thống kê, Vật liệu, Cân ô tô: hàng 1 `Công ty · Trạm`, hàng 2 `Thời gian`. Cấp phối: `Công ty · Trạm` cùng hàng. Chip Công ty chỉ hiện khi tài khoản được chọn nhiều công ty. Bốn loại Thông báo hiện 2×2 khi đủ loại. Chip bộ lọc đang áp dụng ở Quản lý trạm xuống dòng. Tên dài được giới hạn trên chip, còn tên đầy đủ có trong bảng chọn/semantics; bố cục không nhảy hàng khi đổi giá trị.

**Code hiện có:** `FilterChipBar` dùng `SingleChildScrollView` ngang; Thông báo và chip đang áp dụng ở Quản lý trạm cũng cuộn ngang. Các màn đã có phần lớn chip và dữ liệu, nên sửa bố cục tại chỗ hoặc một helper rất nhỏ nếu nhiều màn dùng cùng cách xếp.

**Hoàn tất khi:** mọi chip cần dùng đều thấy được ở 360/390/412px và cỡ chữ 1,3×; tên dài không gây `RenderFlex overflow`; bộ lọc Công ty riêng của SupAdmin vẫn hoạt động; màn rộng không bị thay đổi ngoài ý muốn; widget test hẹp và `flutter analyze` đạt.

**Checkpoint:** `Hoàn tất và đã push` — `1f15799` (`origin/feat/mobile-figma-redesign`). Bộ lọc mobile có hàng cố định; thông báo 2×2 khi có đủ loại; chip đang áp dụng ở Quản lý trạm xuống dòng. Targeted tests `33/33` và station test riêng `1/1`; layout test 360/390/412px × chữ 1,0/1,3 `6/6`; visual đại diện Sáng/Tối đã soát, gồm SupAdmin Đơn hàng và Thông báo. `flutter analyze --no-pub` chỉ còn 1 `info` cũ về `fake_async`; diff check đạt. Chưa chạy full suite.

## Phần 4 — Phạm vi Công ty → Trạm

**Thay đổi:** SupAdmin giữ Công ty riêng và đổi Công ty thì bỏ Trạm không còn thuộc công ty mới. Từ chip Trạm, nếu chưa có Công ty thì đi qua Công ty rồi Trạm; nếu đã có Công ty thì vào thẳng danh sách trạm. Tài khoản chỉ có một Công ty bỏ qua bước đầu. Áp dụng ở Đơn hàng, Thống kê, Vật liệu, Cân ô tô; C17 giữ trường Công ty ở trên Trạm và hiển thị đúng phạm vi. Đơn hàng hỗ trợ `Tất cả trạm của công ty`; ba báo cáo còn lại yêu cầu một trạm cụ thể theo API hiện có. Danh sách công ty/trạm cho xem tên đầy đủ; không lặp tên công ty ở mỗi trạm khi đã trong phạm vi một công ty.

**Code trước phần này:** Đơn hàng đã có chip Công ty và lựa chọn `Tất cả công ty`/`Tất cả trạm`, nhưng chip Trạm vẫn mở danh sách phẳng. Thống kê, Vật liệu, Cân ô tô đã có nhánh chọn Công ty trước khi Trạm; cần kiểm chứng và thêm bước bỏ qua khi chỉ có một công ty. Tận dụng controller/picker đang có, chỉ sửa các lỗ hổng đã xác nhận.

**Hoàn tất khi:** test SupAdmin và một công ty bao phủ chọn/đổi/xóa Công ty, chọn mọi trạm hoặc một trạm, mở lại picker và đổi công ty; không có trạm thuộc công ty khác lọt vào danh sách/kết quả; targeted tests và `flutter analyze` đạt.

**Checkpoint:** `Hoàn tất và đã push` — `67f5b0c` (`origin/feat/mobile-figma-redesign`), gồm phần 4 và tài liệu plan. Đơn hàng có luồng Công ty → Trạm, `Tất cả trạm của công ty`, tên công ty ở đầu picker, và C17 cùng phạm vi. Thống kê/Vật liệu/Cân ô tô dùng luồng có sẵn, bổ sung bỏ qua bước Công ty khi danh sách chỉ có một và hiện tên công ty trong picker. Widget tests màn liên quan `20/20`; visual interaction SupAdmin ba màn và một công ty `4/4`; `flutter analyze --no-pub` chỉ còn 1 `info` cũ về `fake_async`; diff check đạt.

## Kiểm tra cuối

- Chạy toàn bộ `flutter test`, `flutter analyze`, `git diff --check` và các visual/widget test hiện có cho 360/390/412px, Sáng/Tối, tên dài và chữ 1,3×. Ghi số ca, exit code, cùng giới hạn chưa kiểm chứng (đặc biệt máy thật/emulator nếu không có).
- Đối chiếu ảnh các màn chính với Figma; chỉ sửa sai khác thuộc bốn phần trên. Ghi checkpoint cuối và push phần sửa cuối nếu có.
- Các mục cũ trong checkpoint 25/09 (phương án tương phản Home, nhớ trạm lần cuối, số phiếu trên dòng danh sách) cần rà trạng thái riêng; không tự gộp vào đợt này.

**Checkpoint tổng:** `Đã kiểm tra và push` — `flutter test --no-pub` **189/189**, visual `test_visual` **48/48 Sáng** và **48/48 Tối** ở khung iPhone của harness; exit code 0 cho cả ba lượt. Lượt visual đầu phát hiện fixture C15 dùng giờ thực nên ảnh thay đổi theo phút; cố định `now` trong visual test và chạy lại cả hai bộ, đều đạt. `flutter analyze --no-pub`: không có error/warning mới, còn 1 `info` baseline về `fake_async`, exit code 1. `git diff --check` đạt. Chưa kiểm chứng trên thiết bị Android/iOS thật; không suy diễn từ test thành QA máy thật. Commit checkpoint cuối: `ed60878` đã push.
