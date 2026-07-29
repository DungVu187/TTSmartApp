# Checklist Khảo Sát Một Phân Hệ

## 1. Phạm Vi

- Tên phân hệ và use case cần hoàn thành.
- Actor sử dụng và function/role liên quan.
- Màn hình hoặc luồng website tương ứng nếu có.
- Bảng chính, bảng liên kết và dữ liệu đầu ra mobile cần.

## 2. Schema Và Database Object

Kiểm tra tối thiểu:

- Column name, SQL type, length/precision, nullable, identity/default/computed.
- Primary key, foreign key, unique constraint và index.
- Trigger insert/update/delete và bảng bị trigger ghi sang.
- View, stored procedure và function đọc/ghi các bảng liên quan.
- Cascade, soft delete, status flag, audit field và concurrency field.

Truy vấn tham khảo, chỉ thay `<TABLE_NAME>` bằng tên bảng đã xác nhận:

```sql
SELECT columnItem.column_id, columnItem.name, typeItem.name AS SqlType,
       columnItem.max_length, columnItem.precision, columnItem.scale,
       columnItem.is_nullable, columnItem.is_identity, columnItem.is_computed
FROM sys.columns AS columnItem
JOIN sys.types AS typeItem ON typeItem.user_type_id = columnItem.user_type_id
WHERE columnItem.object_id = OBJECT_ID(N'dbo.<TABLE_NAME>')
ORDER BY columnItem.column_id;
```

```sql
SELECT triggerItem.name, triggerItem.is_disabled, moduleItem.definition
FROM sys.triggers AS triggerItem
JOIN sys.sql_modules AS moduleItem ON moduleItem.object_id = triggerItem.object_id
WHERE triggerItem.parent_id = OBJECT_ID(N'dbo.<TABLE_NAME>');
```

```sql
SELECT referencingSchema.name AS SchemaName, referencingObject.name AS ObjectName,
       referencingObject.type_desc
FROM sys.sql_expression_dependencies AS dependency
JOIN sys.objects AS referencingObject ON referencingObject.object_id = dependency.referencing_id
JOIN sys.schemas AS referencingSchema ON referencingSchema.schema_id = referencingObject.schema_id
WHERE dependency.referenced_id = OBJECT_ID(N'dbo.<TABLE_NAME>');
```

## 3. Profile Dữ Liệu

- Đếm tổng bản ghi và bản ghi đang hoạt động/ngừng hoạt động.
- Kiểm tra giá trị null, trùng mã, bản ghi mồ côi và trạng thái thực tế.
- Xem dữ liệu mẫu tối thiểu, chỉ lấy cột cần hiểu nghiệp vụ và che dữ liệu nhạy cảm.
- Xác định timezone, định dạng mã, đơn vị tính, precision tiền/số lượng và quy tắc làm tròn.

## 4. Câu Hỏi Nghiệp Vụ

- Ai được xem, tạo, sửa, duyệt, hủy hoặc xóa?
- Trạng thái chuyển theo thứ tự nào và hành động nào bị cấm?
- Website đang validate gì ở client, backend hoặc database?
- Có thao tác nào gọi procedure hoặc phụ thuộc trigger không?
- Dữ liệu nào bắt buộc đồng bộ với web và dữ liệu nào chỉ dành cho mobile?
- Quyền `Right` của function được giải nghĩa thế nào?

## 5. Contract Mobile

- DTO không chứa tên bảng hoặc field nội bộ không cần thiết.
- Xác định nullable, enum/status, format ngày giờ, phân trang, filter và sort.
- Xác định rõ `400`, `401`, `403`, `404`, `409` và lỗi hệ thống.
- Cung cấp JSON mẫu đã ẩn danh và ghi rõ breaking change.

## 6. Hoàn Thành

- Mapping khớp schema và không tạo migration lên DB clone.
- Test và E2E không để lại dữ liệu tạm hoặc trigger bị disable.
- OpenAPI phản ánh đúng contract.
- Bàn giao rõ object database đã dùng, nghiệp vụ đã xác nhận và câu hỏi còn mở.
