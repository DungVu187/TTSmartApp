# RBAC Permission Matrix

| Function code | Module | Xem | Tạo mới | Cập nhật | Xóa | Nhập | Xuất | In | Khác | D.Sách |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| QLND | User | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| QLQ | Role và ma trận quyền | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| QLCN | Function/menu | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |

## Endpoint mapping

- GET /api/users: QLND bit 8 (D.Sách).
- GET /api/users/{id}: QLND bit 0 (Xem).
- POST /api/users: QLND bit 1.
- PUT /api/users/{id}, status, roles và reset-password: QLND bit 2.
- DELETE /api/users/{id}: QLND bit 3.
- GET /api/roles: QLQ bit 8 (D.Sách).
- GET /api/roles/{id} và /api/roles/{id}/function-matrix: QLQ bit 0 (Xem).
- POST /api/roles: QLQ bit 1.
- PUT role, status, functions và active-key: QLQ bit 2.
- DELETE /api/roles/{id} và /api/roles/{id}/functions/{functionId}: QLQ bit 3.
- GET /api/functions và /api/functions/tree: QLCN bit 8 (D.Sách).
- GET /api/functions/{id}: QLCN bit 0 (Xem).
- POST /api/functions: QLCN bit 1.
- PUT function và status: QLCN bit 2.
- DELETE /api/functions/{id}: QLCN bit 3.
- Nhập, Xuất, In và Khác được giữ trong ActiveKey để các module nghiệp vụ sau dùng đúng bit tương ứng; D.Sách đã áp dụng cho endpoint danh sách.

Đầy đủ là trạng thái UI khi toàn bộ 9 bit bằng 1; không phải quyền thứ 10.

## Quy tắc hợp quyền

Các assignment hiệu lực của toàn bộ Role của User được OR từng vị trí. Assignment phải có Type = 2, TargetId = RoleId, Status = 1; Function và Role cũng phải Status = 1.
