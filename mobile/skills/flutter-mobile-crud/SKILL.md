---
name: flutter-mobile-crud
description: Xây dựng và bảo trì luồng CRUD cho bất kỳ phân hệ Flutter nào sử dụng REST API ASP.NET Core, gồm danh sách, chi tiết, thêm, sửa, xóa, tìm kiếm, lọc, phân trang, làm mới, form validation và trạng thái tải, rỗng, lỗi, thử lại. Dùng khi Codex làm DTO Dart, API client, repository, controller, màn hình dữ liệu, điều hướng hoặc test CRUD trong repository mobile này. Tôn trọng kiến trúc và state management hiện có; không làm backend, không sửa SQL Server và không kết nối Flutter trực tiếp database.
---

# Flutter Mobile CRUD

## Giữ Đúng Phạm Vi

1. Đọc `D:\TTSmartApp\AGENTS.md` và `D:\TTSmartApp\mobile\AGENTS.md`.
2. Chỉ làm mobile Flutter; xem backend API là hệ thống bên ngoài.
3. Không kết nối Flutter trực tiếp SQL Server.
4. Không suy đoán nghiệp vụ từ tên bảng, tên field hoặc một module mẫu.
5. Dùng `flutter-business-module` trước nếu chưa rõ ranh giới và use case của phân hệ.

## Kiểm Tra Trước Khi Triển Khai

1. Kiểm tra source, `pubspec.yaml`, routing, API client, state management, theme và test hiện có.
2. Tái sử dụng package và quy ước sẵn có trước khi thêm dependency.
3. Đọc OpenAPI, DTO, JSON mẫu hoặc backend test của endpoint cần dùng.
4. Xác định xác thực, quyền, response envelope, phân trang, nullable, enum, ngày giờ và lỗi validation.
5. Xác nhận create, update và delete có hành vi nghiệp vụ gì, không chỉ dựa vào HTTP method.

Không tự chuyển package HTTP, state management hoặc navigation nếu giải pháp hiện tại vẫn phù hợp.

## Xác Định Hợp Đồng API

Xác nhận tối thiểu:

- Base URL và header theo môi trường.
- Cơ chế xác thực và function quyền.
- Endpoint danh sách, chi tiết, thêm, sửa và xóa.
- Query tìm kiếm, lọc, sắp xếp và phân trang.
- JSON request và response mẫu.
- Mã trạng thái thành công và `ProblemDetails` lỗi.
- Kiểu định danh, nullable, enum, số và ngày giờ.
- Update toàn phần hay một phần; delete cứng, mềm hay đổi trạng thái.

Dùng `references/api-contract-checklist.md` khi contract chưa đầy đủ.

## Tổ Chức Feature

Ưu tiên cấu trúc tương đương:

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

- Không đặt HTTP call hoặc parse JSON trong widget.
- Đặt DTO và ánh xạ response gần data layer.
- Đặt networking và chuyển đổi lỗi dùng chung trong `lib/core/`.
- Đặt validation và UI riêng trong feature.
- Chỉ thêm domain layer khi có logic nghiệp vụ mobile độc lập hoặc cần ranh giới thật sự.

## Triển Khai Luồng CRUD

### Danh Sách

- Hiển thị loading ban đầu, empty state, error và retry rõ ràng.
- Hỗ trợ làm mới và giữ dữ liệu cũ trong lúc refresh khi phù hợp.
- Tìm kiếm server cần debounce và hủy hoặc bỏ qua response cũ.
- Không để widget rebuild tạo request lặp.
- Phân trang không thêm trùng item và xử lý hết dữ liệu.

### Chi Tiết

- Tải bằng định danh ổn định do server cấp.
- Xử lý riêng `404`, dữ liệu đã xóa hoặc quyền bị thay đổi.
- Sau cập nhật, làm mới dữ liệu hoặc trả kết quả qua điều hướng có chủ đích.

### Thêm Và Sửa

- Tái sử dụng field và validation khi form có cùng cấu trúc.
- Phân biệt giá trị mặc định khi thêm và dữ liệu ban đầu khi sửa.
- Chuẩn hóa chuỗi và nullable theo contract trước khi gửi.
- Chặn submit lặp và giữ dữ liệu đã nhập sau lỗi có thể khắc phục.
- Ánh xạ validation backend về đúng field khi có thể.
- Không gửi field chỉ đọc hoặc field do server sinh.

### Xóa Hoặc Đổi Trạng Thái

- Hiển thị xác nhận có thông tin nhận diện bản ghi.
- Chặn thao tác lặp khi request đang chạy.
- Chỉ cập nhật UI sau khi server xác nhận thành công.
- Giải thích rõ `403`, `404` và `409` thay vì báo lỗi chung.
- Không giả định endpoint DELETE là xóa cứng nếu backend chưa xác nhận.

## Xử Lý Lỗi Nhất Quán

Chuyển lỗi tầng thấp thành nhóm ổn định:

- Mất mạng hoặc timeout.
- Chưa đăng nhập hoặc phiên hết hạn.
- Không có quyền.
- Không tìm thấy dữ liệu.
- Dữ liệu không hợp lệ.
- Xung đột dữ liệu.
- Lỗi server.
- Response sai cấu trúc.

Hiển thị thông báo tiếng Việt ngắn gọn và có hướng xử lý. Không hiển thị payload thô, stack trace hoặc ghi token, mật khẩu và secret vào log.

## UI Mobile

- Tôn trọng `SafeArea`, bàn phím, cuộn, focus và nút quay lại.
- Dùng danh sách, card hoặc màn chi tiết thay cho bảng desktop rộng.
- Đặt hành động chính dễ tiếp cận và vùng chạm đủ lớn.
- Tránh card lồng card, gradient trang trí và thông tin quá dày.
- Ưu tiên thông tin nhận diện, trạng thái và dữ liệu hỗ trợ quyết định trong mỗi item.
- Thể hiện rõ loading, empty, error, retry, disabled, pressed và validation state.

## Kiểm Tra Trước Khi Bàn Giao

Dùng `references/quality-checklist.md` và tối thiểu:

1. Format file Dart đã thay đổi.
2. Chạy `flutter analyze`.
3. Chạy unit test và widget test liên quan.
4. Kiểm tra parse model bằng JSON mẫu thật.
5. Kiểm tra query và payload đúng nullable, enum và ngày giờ.
6. Kiểm tra loading, empty, error, retry, validation và submit lặp.
7. Kiểm tra `401`, `403`, `404` và `409` khi có liên quan.
8. Báo cáo endpoint hoặc nghiệp vụ chưa thể xác minh.
