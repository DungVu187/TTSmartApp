# Checklist Khảo Sát Phân Hệ

## Nghiệp Vụ

- Tên phân hệ và mục tiêu.
- Người dùng hoặc vai trò nghiệp vụ liên quan.
- Phạm vi toàn công ty, nhóm trạm hoặc từng trạm.
- Use case bắt buộc trong phiên bản đầu.
- Hành vi website đã quan sát hoặc tài liệu đã nhận.
- Quy tắc, trạng thái và thuật ngữ đã được xác nhận.
- Điểm chưa rõ và người cần xác nhận.

## Quyền Và Điều Hướng

- `function.name` backend.
- Điều kiện quyền hiện hành.
- Route mobile và vị trí trong App Shell.
- Hành vi khi không có function hoặc nhận `403`.
- Deep link hoặc route trực tiếp có cần bảo vệ hay không.
- Cách xác định trạm hiện tại và quyền chuyển trạm.

## API

- Endpoint, method và header.
- Request, response và JSON mẫu.
- Định danh, nullable, enum, ngày giờ và số thập phân.
- Phân trang, tìm kiếm, lọc và sắp xếp.
- Validation error, `401`, `403`, `404`, `409` và lỗi server.
- Contract còn thiếu hoặc có nguy cơ thay đổi.
- Mã trạm lấy từ authentication, cấu hình server hay tham số đã authorization.

## Mobile UX

- Màn hình và thứ tự điều hướng.
- Thông tin ưu tiên trên màn hình nhỏ.
- Hành động chính, hành động phụ và thao tác phá hủy.
- Loading, empty, error, retry và offline behavior nếu có.
- Khác biệt dự kiến so với website.
