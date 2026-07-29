# Checklist Hợp Đồng API CRUD

## Cấu Hình Dùng Chung

- Base URL của Development, Staging và Production.
- Cơ chế xác thực, refresh token nếu có và function quyền.
- Cách xác định phạm vi toàn công ty hoặc trạm và nơi backend kiểm tra quyền trạm.
- Header bắt buộc, content type và metadata client.
- Timeout, retry và response envelope dùng chung.
- Cấu trúc `ProblemDetails` và validation error.

## Model Phân Hệ

- Kiểu và tên field của định danh ổn định.
- Field bắt buộc, field nullable và field chỉ đọc.
- Quy tắc duy nhất của mã hoặc khóa nghiệp vụ.
- Giá trị hợp lệ của trạng thái và enum.
- Định dạng ngày, giờ và múi giờ.
- Độ chính xác của decimal hoặc field số.
- Field do server sinh và field mobile được phép gửi.

## Endpoint

Với từng endpoint danh sách, chi tiết, thêm, sửa và xóa hoặc đổi trạng thái:

- HTTP method và đường dẫn.
- Path parameter, query parameter và body.
- JSON request và response mẫu.
- Mã trạng thái thành công.
- Phân trang, tìm kiếm, lọc và sắp xếp.
- Tham số trạm, giá trị mặc định và hành vi khi truy cập trạm không được phép.
- Validation error và lỗi `401`, `403`, `404`, `409`, `500`.
- Update toàn phần hay một phần.
- Delete cứng, mềm hay chuyển trạng thái.

## Lưu Ý Mobile

- Không suy luận bảng hoặc cột SQL Server từ field API.
- Không gửi giá trị giả cho field chưa được xác nhận.
- Giữ ánh xạ chưa chắc chắn trong DTO hoặc adapter.
- Chỉ dùng mock fixture khi được đánh dấu rõ và thay bằng JSON thật khi backend cung cấp.
