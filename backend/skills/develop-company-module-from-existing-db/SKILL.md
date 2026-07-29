---
name: develop-company-module-from-existing-db
description: Khảo sát và triển khai từng phân hệ backend ASP.NET Core từ database SQL Server và website hiện có của công ty. Dùng khi làm việc với dangnhap.net, TTSmartMobile_Dev hoặc database clone; khi cần phân tích table, relation, view, stored procedure, trigger, dữ liệu và phân quyền; khi map EF Core database-first; hoặc khi xây REST API cho Flutter mà không được tự suy diễn nghiệp vụ hay chạy migration lên database gốc.
---

# Phát Triển Phân Hệ Từ Database Công Ty

## Chuẩn Bị

1. Đọc `D:\TTSmartApp\AGENTS.md` và `backend/AGENTS.md`.
2. Xác định database nguồn, database clone, phân hệ, actor và use case nhỏ cần hoàn thành.
3. Mặc định chỉ đọc database nguồn; chỉ thao tác trên clone khi người dùng đã cho phép.
4. Không chạy script clone, restore, drop, migration hoặc seed nếu chưa có chấp thuận rõ ràng.
5. Đọc `references/module-discovery-checklist.md` trước khi thiết kế mapping.

## Khảo Sát Phân Hệ

- Liệt kê bảng chính, bảng liên kết, PK, FK, index, default, check constraint và computed column.
- Kiểm tra view, stored procedure, function và trigger tham chiếu các bảng liên quan.
- Profile dữ liệu an toàn: số lượng, nullable, trạng thái, giá trị trùng, bản ghi mồ côi và khoảng ngày; không in secret hoặc dữ liệu cá nhân không cần thiết.
- Xác định Function/Role/ActiveKey điều khiển phân hệ.
- Nếu có website, quan sát trường hiển thị, bộ lọc, thứ tự thao tác, validation, trạng thái và kết quả hành động.
- Ghi riêng: nghiệp vụ đã xác nhận, hành vi suy ra từ database và câu hỏi còn mở.

## Thiết Kế Mapping Và API

- Chỉ map entity cần cho use case hiện tại; không scaffold toàn bộ database.
- Giữ nguyên tên bảng/cột, typo legacy, kiểu SQL, nullable, khóa và relationship.
- Không viết lại logic đã nằm trong trigger/procedure nếu chưa đánh giá side effect và nguy cơ chạy trùng.
- Tách entity khỏi DTO; thiết kế API cho mobile theo nghiệp vụ, không theo cấu trúc bảng.
- Chốt validation, status code, phân trang, filter, sort, lỗi và authorization trước khi code.
- Giữ contract cộng thêm và tương thích ngược khi mobile đã tích hợp.

## Triển Khai

- Đặt code theo `Features/<TênPhânHệ>` và giữ controller mỏng.
- Dùng EF Core async, `CancellationToken`, `AsNoTracking` và projection phù hợp.
- Dùng transaction khi use case thay đổi nhiều bảng hoặc phụ thuộc trigger/procedure.
- Áp quyền backend dựa trên Function/ActiveKey đã được xác nhận; không hardcode suy diễn bit quyền.
- Không dùng migration hoặc `EnsureCreated` trên database clone công ty.
- Test data trên clone phải có định danh, rollback/dọn sạch và kiểm tra trigger được bật lại.

## Xác Minh

- So sánh kết quả API với truy vấn SQL và hành vi web đã biết.
- Kiểm tra trường hợp success, empty, invalid, not found, conflict, unauthorized và forbidden.
- Chạy test feature, format, test solution và build Release.
- Kiểm tra OpenAPI và JSON thực tế để bàn giao cho mobile.
- Báo cáo database object đã dùng, nghiệp vụ đã xác nhận, giả định còn lại và bước nhỏ tiếp theo.
