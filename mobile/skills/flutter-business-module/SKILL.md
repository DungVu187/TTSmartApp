---
name: flutter-business-module
description: Khảo sát, thiết kế và triển khai từng phân hệ nghiệp vụ trong ứng dụng Flutter nội bộ dựa trên yêu cầu người dùng, hành vi website công ty đã xác minh và REST API ASP.NET Core. Dùng khi Codex thêm module mới, App Shell, menu động theo function, route guard, luồng nhiều màn hình, chuyển use case từ web sang mobile, phối hợp contract với backend hoặc cần xác định vertical slice đầu tiên. Không sửa backend hoặc SQL Server và không suy diễn nghiệp vụ chỉ từ tên bảng hay field.
---

# Flutter Business Module

## Giữ Đúng Vai Trò

1. Chỉ triển khai mobile Flutter.
2. Đọc `D:\TTSmartApp\AGENTS.md` và `D:\TTSmartApp\mobile\AGENTS.md` trước khi làm phân hệ.
3. Xem backend và database là nguồn bên ngoài; chỉ tích hợp qua API contract.
4. Không tuyên bố giống website nếu chưa đối chiếu được hành vi thực tế.
5. Không biến giả định của một phân hệ thành quy tắc chung cho toàn app.

## Khảo Sát Phân Hệ

Trước khi code, xác định tối thiểu:

- Tên phân hệ và mục tiêu nghiệp vụ.
- Nhóm người dùng và hành động chính.
- Phạm vi toàn công ty, một nhóm trạm hay một trạm cụ thể.
- Hành vi website hoặc tài liệu đã được xác nhận.
- Function quyền, route và vị trí menu.
- Màn hình cần có trong phiên bản đầu.
- Endpoint, request, response, lỗi và trạng thái backend.
- Dữ liệu bắt buộc, nullable, enum, ngày giờ và định danh.
- Điểm chưa rõ cần người dùng hoặc backend xác nhận.

Dùng `references/module-discovery-checklist.md` để ghi nhận phạm vi trước khi triển khai.

## Chọn Vertical Slice

- Chọn use case nhỏ nhất tạo được giá trị và chạy xuyên suốt từ menu đến API và UI.
- Ưu tiên hoàn thành một luồng thật thay vì tạo nhiều màn hình placeholder.
- Với phân hệ lớn, triển khai theo thứ tự hợp lý như danh sách, chi tiết, thao tác chính, sau đó mới mở rộng quản trị hoặc báo cáo.
- Giữ phần chưa có contract ở ranh giới DTO, repository hoặc feature flag dễ thay đổi.
- Không tạo kiến trúc cho các use case tương lai chưa được xác nhận.

## App Shell Và Phân Quyền

- Đăng ký module trong registry tập trung bằng `function.name`, route, nhãn, mô tả và icon.
- Chỉ hiển thị module khi phiên hiện tại có function phù hợp và quyền theo contract backend.
- Không dùng tên role làm điều kiện mở module.
- Route guard phải kiểm tra lại quyền, kể cả khi menu đã bị ẩn.
- `401` xóa phiên và quay về Login; `403` giữ phiên và hiển thị không có quyền.
- Function backend chưa có mapping mobile phải được bỏ qua an toàn và báo cáo khi bàn giao.
- Phạm vi trạm phải lấy từ contract đã được backend authorization kiểm tra; không tin tưởng mã trạm chỉ vì mobile gửi lên.

## Tổ Chức Source

Ưu tiên cấu trúc theo feature:

```text
lib/features/<feature_name>/
  data/
    models/
    repositories/
  presentation/
    controllers/
    screens/
    widgets/
```

- Không gọi HTTP hoặc parse JSON trong widget.
- Tái sử dụng API client, session, theme, navigation và error mapping trong `lib/core/`.
- Tách DTO khỏi state UI khi contract backend không phù hợp trực tiếp với hiển thị.
- Dùng state management hiện có; chỉ thêm package khi có nhu cầu cụ thể.
- Không tạo abstraction dùng chung trước khi có ít nhất hai nhu cầu thực sự giống nhau.

## Chuyển Luồng Web Sang Mobile

- Giữ nguyên thuật ngữ, dữ liệu và quy tắc nghiệp vụ đã xác nhận.
- Không sao chép bảng desktop hoặc bố cục nhiều cột nguyên trạng.
- Chọn thông tin ưu tiên cho màn hình nhỏ; đưa phần phụ vào chi tiết, filter hoặc bottom sheet.
- Đặt hành động thường dùng ở vị trí dễ tiếp cận và hành động phá hủy sau xác nhận.
- Nêu rõ khác biệt khi mobile rút gọn hoặc chia nhỏ luồng web.

## Phối Hợp Backend

Khi contract thiếu hoặc cần đổi, gửi yêu cầu có cấu trúc:

- Use case mobile cần hỗ trợ.
- Endpoint và HTTP method đề xuất hoặc đang thiếu.
- Request, response và JSON mẫu.
- Status code và `ProblemDetails` mong đợi.
- Quyền function cần kiểm tra.
- Lý do, ảnh hưởng và yêu cầu tương thích ngược.

Không tự sửa backend để né việc làm rõ contract.

## Kiểm Tra Trước Khi Bàn Giao

Dùng `references/module-delivery-checklist.md` và tối thiểu:

1. Format code Dart đã sửa.
2. Chạy `flutter analyze`.
3. Chạy unit test và widget test liên quan.
4. Kiểm tra menu động, route guard, `401` và `403` khi có phân quyền.
5. Kiểm tra phạm vi toàn công ty hoặc từng trạm và từ chối truy cập chéo trạm khi có liên quan.
6. Kiểm tra loading, empty, error, retry và trạng thái thao tác.
7. Build nền tảng bị ảnh hưởng khi môi trường hỗ trợ.
8. Báo cáo nghiệp vụ đã xác nhận, giả định, contract chưa xác minh và phụ thuộc backend.
