# Contract Mặc Định Cho CRUD Nhân Viên

> Chỉ dùng tài liệu này cho module nhân viên greenfield khi chưa map bảng `NHANVIEN` của database công ty. Không dùng contract mẫu để thay thế schema hoặc nghiệp vụ hiện có.

Dùng contract này khi người dùng yêu cầu quản lý nhân viên cơ bản nhưng chưa quy định chi tiết dữ liệu. Yêu cầu nghiệp vụ trực tiếp luôn được ưu tiên.

## Dữ Liệu Nhân Viên

| Trường | Kiểu C# | Quy tắc |
| --- | --- | --- |
| `Id` | `int` | Khóa chính identity của SQL Server |
| `EmployeeCode` | `string` | Bắt buộc, tối đa 32 ký tự, duy nhất |
| `FullName` | `string` | Bắt buộc, tối đa 150 ký tự |
| `Email` | `string` | Bắt buộc, tối đa 254 ký tự, duy nhất |
| `PhoneNumber` | `string?` | Không bắt buộc, tối đa 20 ký tự |
| `DateOfBirth` | `DateOnly?` | Không bắt buộc, cột SQL `date` |
| `Gender` | `string?` | Không bắt buộc, tối đa 20 ký tự |
| `Department` | `string?` | Không bắt buộc, tối đa 100 ký tự |
| `Position` | `string?` | Không bắt buộc, tối đa 100 ký tự |
| `HireDate` | `DateOnly` | Bắt buộc, cột SQL `date` |
| `IsActive` | `bool` | Bắt buộc, mặc định `true` |
| `CreatedAtUtc` | `DateTime` | Server tự gán |
| `UpdatedAtUtc` | `DateTime?` | Server cập nhật sau khi sửa |

## Endpoint

| Phương thức | Route | Thành công | Lỗi dự kiến |
| --- | --- | --- | --- |
| `GET` | `/api/employees` | `200 OK` | `400` khi query không hợp lệ |
| `GET` | `/api/employees/{id}` | `200 OK` | `404` khi không có nhân viên |
| `POST` | `/api/employees` | `201 Created` | `400` validation, `409` trùng mã hoặc email |
| `PUT` | `/api/employees/{id}` | `204 No Content` | `400` validation, `404` không có dữ liệu, `409` trùng dữ liệu |
| `DELETE` | `/api/employees/{id}` | `204 No Content` | `404` khi không có nhân viên |

## Query Danh Sách

- Nhận `pageNumber`, `pageSize`, `search` và `isActive` không bắt buộc.
- Mặc định `pageNumber` là `1`, `pageSize` là `20`, giới hạn `pageSize` tối đa `100`.
- Tìm kiếm không phân biệt hoa thường theo mã nhân viên, họ tên, email, phòng ban và chức vụ.
- Mặc định sắp xếp theo `FullName`, sau đó theo `Id` để thứ tự ổn định.
- Response gồm `items`, `totalCount`, `pageNumber`, `pageSize` và `totalPages`.

## Hành Vi

- Chuẩn hóa mã nhân viên và email trước khi kiểm tra trùng.
- Mặc định xóa cứng vì chưa có yêu cầu soft delete.
- Chưa thêm authentication trong phiên bản CRUD đầu tiên nếu người dùng không yêu cầu.
- Không trả entity EF Core hoặc chi tiết exception nội bộ cho client.
- Lỗi validation và lỗi server phải tương thích với chuẩn `ProblemDetails`.
