# Khảo Sát Phạm Vi User - Branch

Cập nhật ngày 30/07/2026.

## Phạm Vi

- Khảo sát read-only trên `TTSmartMobile_Dev`.
- Không chạy thao tác ghi và không thay đổi `dangnhap.net`.
- Mục tiêu là đánh giá ảnh hưởng của validation `User.CompanyId` và `User.BranchId` trước khi áp dụng cho API mobile.

## Kết Quả

- Có 98 User `Status = 1` đang lưu `BranchId` khác rỗng.
- Không phát hiện token `BranchId` sai định dạng hoặc trỏ tới Branch không tồn tại trong nhóm này.
- Phát hiện 4 assignment có Branch thuộc Company khác `User.CompanyId`.
- Trong 4 trường hợp, 3 User có Role `CONGTY`; `BranchId` không quyết định phạm vi vì Role này xem toàn bộ Branch thuộc Company.
- Một User Role `QUANLY` có assignment chéo Company và được coi là dữ liệu legacy cần giữ tương thích.

## Quy Tắc Backend Áp Dụng

- User mới do tài khoản công ty tạo với Role thấp hơn `CONGTY` phải có ít nhất một Branch đang hiệu lực thuộc đúng Company.
- Khi Company, Role hoặc Branch assignment thay đổi, backend kiểm tra lại toàn bộ assignment và từ chối Branch chéo Company.
- Khi chỉ sửa hồ sơ và Company/Role/Branch không thay đổi, backend cho phép giữ nguyên assignment legacy để không chặn việc cập nhật dữ liệu cũ.
- Khi User được chuyển sang Role `ADMIN` hoặc `CONGTY`, Branch không còn là nguồn data scope.
- Backend không tự sửa, xóa hoặc di chuyển các dòng legacy trong database.

## Kiểm Tra Liên Quan

- `UserAssignmentValidationTests` kiểm tra Branch bắt buộc, Branch cùng Company, chuẩn hóa danh sách và tương thích assignment legacy.
- SQL E2E gửi `branchId` khi tạo/cập nhật User để kiểm tra translation và dữ liệu thật trên `TTSmartMobile_Dev`.