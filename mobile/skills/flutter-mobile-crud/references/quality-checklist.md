# Checklist Chất Lượng CRUD Mobile

## Kiến Trúc

- Widget không gọi HTTP trực tiếp.
- Base URL, header, token và lỗi được quản lý tập trung.
- DTO xử lý có chủ đích field thiếu, null và dữ liệu ngoài dự kiến.
- Repository và state tuân theo quy ước hiện tại của dự án.
- Không hardcode role, credential, secret hoặc cấu trúc database.

## Hành Vi

- Danh sách có loading, refresh, empty, error và retry.
- Tìm kiếm và phân trang không tạo request hoặc item trùng.
- Chi tiết xử lý dữ liệu không tồn tại hoặc không còn quyền.
- Thêm và sửa chặn submit lặp, giữ dữ liệu sau lỗi.
- Xóa hoặc đổi trạng thái yêu cầu xác nhận khi phù hợp.
- `401` đi theo luồng phiên; `403` không tự đăng xuất.
- Dữ liệu theo trạm hiển thị đúng phạm vi và không cho đổi tham số để truy cập chéo trạm.

## Giao Diện

- Màn hình tôn trọng safe area và bàn phím.
- Form sử dụng được trên màn hình nhỏ.
- Vùng chạm có kích thước phù hợp.
- Lỗi ngắn gọn và có hướng xử lý.
- Không truyền đạt trạng thái chỉ bằng màu sắc.
- Loading và disabled dễ nhận biết.

## Xác Minh

- Code Dart đã format.
- `flutter analyze` không có lỗi trong phần bị ảnh hưởng.
- Unit test và widget test liên quan thành công.
- JSON mẫu thật parse đúng.
- Query và payload khớp contract.
- Giả định API và nghiệp vụ chưa xác minh được báo cáo.
