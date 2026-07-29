---
name: build-aspnet-sqlserver-api
description: Xây dựng, mở rộng, rà soát và kiểm tra ASP.NET Core Web API dùng Entity Framework Core và SQL Server cho ứng dụng mobile nội bộ. Dùng khi tạo hoặc sửa controller, service, DTO, validation, authentication, authorization, truy cập dữ liệu, OpenAPI, xử lý lỗi và test. Khi chức năng dựa trên database công ty hiện có, phải dùng kèm skill develop-company-module-from-existing-db.
---

# Xây Dựng ASP.NET Core API Với SQL Server

## Thiết Lập Ngữ Cảnh

1. Đọc tất cả `AGENTS.md` áp dụng cho file sẽ thay đổi.
2. Kiểm tra solution, project, package, cấu hình, API contract và pattern của feature gần nhất.
3. Xác định chế độ dữ liệu trước khi sửa code:
   - Database công ty hiện có: đọc thêm `../develop-company-module-from-existing-db/SKILL.md` và không tự tạo migration.
   - Database greenfield độc lập: có thể dùng EF Core migrations sau khi schema đã được chốt.
4. Giữ kiến trúc hiện hữu; không tạo lại project hoặc thêm tầng kiến trúc chỉ vì ví dụ mẫu.

## Quy Trình Làm Feature

1. Xác định actor, use case, dữ liệu và quyền liên quan.
2. Chốt request, response, validation, status code và quy tắc dữ liệu duy nhất.
3. Map entity/configuration tối thiểu cho dữ liệu cần dùng.
4. Tách request DTO và response DTO; không bind hoặc trả entity trực tiếp.
5. Đặt truy cập dữ liệu và nghiệp vụ trong service/feature; giữ controller mỏng.
6. Dùng EF Core bất đồng bộ và truyền `CancellationToken` qua các tầng.
7. Áp authentication/authorization tại backend, không dựa vào việc mobile ẩn nút.
8. Viết test cho thành công, validation, không tìm thấy, xung đột, quyền và hành vi SQL quan trọng.
9. Kiểm tra OpenAPI, format, test, build và E2E phù hợp.

## Quy Ước API

- Dùng route tài nguyên rõ nghĩa và nhất quán với module hiện tại.
- Khi tạo thành công, ưu tiên `201 Created`; cập nhật thành công dùng status code đã chốt trong contract.
- Dùng `404` khi tài nguyên không tồn tại, `409` cho xung đột dữ liệu, `401` cho phiên không hợp lệ và `403` cho thiếu quyền.
- Lỗi validation dùng `ValidationProblemDetails`; lỗi khác dùng `ProblemDetails` tập trung.
- Endpoint danh sách phải có thứ tự ổn định; thêm phân trang, filter và search khi dữ liệu có thể lớn.
- API JSON dùng `camelCase`; thời gian dùng ISO 8601/UTC và ngày thuần dùng `yyyy-MM-dd`.
- Không làm mobile phụ thuộc tên bảng, stored procedure hoặc cấu trúc EF Core nội bộ.

## Quy Ước EF Core Và SQL Server

- Cấu hình rõ column name, độ dài, nullable, kiểu SQL, khóa, relationship và concurrency nếu có.
- Dùng `AsNoTracking` và projection cho truy vấn chỉ đọc.
- Tránh N+1, client-side evaluation và tải dữ liệu thừa.
- Dùng truy vấn tham số hóa; raw SQL/stored procedure phải có input/output và transaction rõ ràng.
- Với database hiện có, giữ nguyên schema và không chạy migration, `EnsureCreated` hoặc seeder tự động.
- Với database greenfield, kiểm tra migration trước khi áp dụng và không tạo thay đổi phá hủy dữ liệu nếu chưa được chấp thuận.
- Không commit connection string production, secret, token hoặc tài khoản database.

## Cấu Trúc Code

- Target hiện tại là `net10.0`, nullable reference types và implicit usings.
- Ưu tiên `Features/<TênPhânHệ>`, `Data` và `Common` theo cấu trúc repository.
- Không tự thêm Generic Repository, MediatR, AutoMapper hoặc nhiều class library nếu chưa có nhu cầu thật.
- Không để placeholder, TODO hoặc code bị comment thay cho logic chạy được.

## Kiểm Tra

- Chạy test hẹp nhất của feature trước.
- Chạy `dotnet format TTSmart.sln --verify-no-changes --no-restore`.
- Chạy `dotnet test TTSmart.sln -c Release --no-restore`.
- Chạy `dotnet build TTSmart.sln -c Release --no-restore`.
- Dùng DB clone để kiểm tra SQL translation, collation, trigger, procedure và transaction khi test InMemory không đủ.

## Tài Liệu Tham Khảo

- Chỉ đọc `references/employee-crud-contract.md` khi người dùng yêu cầu CRUD nhân viên greenfield và chưa map bảng `NHANVIEN` của database công ty.
- Schema và nghiệp vụ công ty luôn ưu tiên hơn contract mẫu.
