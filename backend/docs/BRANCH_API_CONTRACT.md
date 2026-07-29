# API Quản Lý Trạm Cho Mobile

## 1. Phạm Vi

- Base route: `/api/branches`.
- Function phân quyền: `QLTT` - Quản lý trạm.
- `ADMIN` là Super Admin, xem toàn bộ dữ liệu và bỏ qua `ActiveKey`.
- `CONGTY` chỉ xem trạm có `Branch.CompanyId` trùng `User.CompanyId`.
- Role thấp hơn chỉ xem các trạm có ID số hợp lệ trong chuỗi `User.BranchId`; token legacy như `undefined` hoặc `[object Object]` bị bỏ qua.
- `TypeTram = 1`: trạm trộn; `TypeTram = 2`: trạm cân.

## 2. Quyền ActiveKey

| API | Bit quyền | Giới hạn nghiệp vụ |
|---|---|---|
| Danh sách | D.Sách | Theo data scope |
| Chi tiết | Xem | Theo data scope |
| Tạo | Tạo mới | Chỉ ADMIN, dù role khác có bit |
| Sửa | Cập nhật | ADMIN; CONGTY chỉ sửa allowlist |
| Xóa mềm | Xóa | Chỉ ADMIN |
| Khôi phục | Cập nhật | Chỉ ADMIN |

- Có D.Sách nhưng không có Xem: chỉ gọi được danh sách.
- Có Xem nhưng không có D.Sách: gọi được chi tiết trực tiếp nếu trạm thuộc data scope.
- Role thấp hơn CONGTY không được sửa, kể cả có bit Cập nhật.

## 3. Danh Sách

### GET /api/branches

Query:

- `pageNumber`: mặc định `1`.
- `pageSize`: mặc định `10`, tối đa `100`.
- `search`: tìm chung theo `Branch.Code` hoặc `Branch.Name`.
- `companyId`: chỉ ADMIN dùng để lọc theo công ty; CONGTY chỉ được gửi đúng CompanyId của mình.
- `typeTram`: `1` hoặc `2`; bỏ trống để lấy cả hai loại.
- `status`: `1` hoặc `99`; mặc định `1`. Chỉ ADMIN được xem `99`.

Backend áp data scope, search và filter trên toàn bộ dữ liệu trước, sau đó sắp xếp `Name ASC`, `BranchId ASC` và mới phân trang.

Response danh sách chỉ gồm ID kỹ thuật và ba trường hiển thị:

    {
      "items": [
        {
          "id": 118,
          "name": "Trạm trộn số 1",
          "phone": "0900000000",
          "typeTram": 1
        }
      ],
      "pageNumber": 1,
      "pageSize": 10,
      "totalCount": 1,
      "totalPages": 1
    }

## 4. Chi Tiết

### GET /api/branches/{id}

Ví dụ response:

    {
      "id": 118,
      "companyId": 22,
      "companyName": "Công ty A",
      "code": "tram1",
      "name": "Trạm trộn số 1",
      "email": "tram1@example.com",
      "phone": "0900000000",
      "address": "Hà Nội",
      "typeTram": 1,
      "username": "tram1_user",
      "password": "••••••••",
      "pmqlXe": null,
      "qlCamera": null,
      "status": 1,
      "isActive": true,
      "createdAtUtc": "2026-07-29T02:00:00Z",
      "updatedAtUtc": "2026-07-29T02:00:00Z"
    }

- API không trả mật khẩu thật. Chuỗi `••••••••` chỉ dùng để hiển thị.
- Với CONGTY, `typeTram`, `username` và `password` là read-only trên mobile.

## 5. Tạo Trạm

### POST /api/branches

Chỉ ADMIN. Request:

    {
      "companyId": 22,
      "code": "tram1",
      "name": "Trạm trộn số 1",
      "email": "tram1@example.com",
      "phone": "0900000000",
      "address": "Hà Nội",
      "username": "tram1_user",
      "password": "Abc123@#",
      "pmqlXe": null,
      "qlCamera": null,
      "typeTram": 1
    }

- Bắt buộc: `companyId`, `code`, `name`, `email`, `phone`, `username`, `password`, `typeTram`.
- Được để trống: `address`, `pmqlXe`, `qlCamera`.
- Company phải tồn tại và có `Status = 1`.
- Backend tự đặt `Status = 1`, `CreatedAt`, `UpdatedAt` và `UserId`.
- Mật khẩu mới tối thiểu 8 ký tự, có chữ thường, chữ hoa, số và ký tự thuộc `@#$%`.
- Mật khẩu Branch được ghi theo cách legacy hiện tại để website tiếp tục sử dụng; mobile chỉ gửi qua HTTPS và không lưu/log payload nhạy cảm.

## 6. Sửa Trạm

### PUT /api/branches/{id}

- ADMIN được sửa các trường trong request, gồm Company, loại trạm, tài khoản và mật khẩu.
- CONGTY phải có bit Cập nhật, trạm phải thuộc đúng CompanyId và chỉ được sửa:
  - `code`
  - `name`
  - `email`
  - `phone`
  - `address`
  - `pmqlXe`
  - `qlCamera`
- Các field `companyId`, `typeTram`, `username`, `password` gửi bởi CONGTY bị backend bỏ qua.
- Field không gửi hoặc `null` được giữ nguyên. Với field tùy chọn, gửi chuỗi rỗng để xóa giá trị.
- Password `••••••••`, chuỗi toàn dấu tròn hoặc dấu sao được coi là masked và không ghi lại database.
- Backend tự cập nhật `UpdatedAt`.

## 7. Mã Và Tài Khoản Trạm

- `Branch.Code` được trim và phân biệt hoa/thường.
- Code chỉ duy nhất giữa Branch `Status = 1`; Code của Branch `Status = 99` được dùng lại.
- `Branch.Username` được trim và duy nhất giữa Branch `Status = 1`; username của Branch `Status = 99` được dùng lại.
- Trùng Code trả `409 Conflict`, detail `Mã trạm đã tồn tại.`.
- Trùng Username trả `409 Conflict`, detail `Tài khoản trạm đã tồn tại.`.
- Khôi phục phải kiểm tra lại Code và Username vì chúng có thể đã được trạm khác sử dụng.

## 8. Xóa Và Khôi Phục

### DELETE /api/branches/{id}

- Chỉ ADMIN.
- Xóa mềm bằng `Branch.Status = 99`.

### POST /api/branches/{id}/restore

- Chỉ ADMIN.
- Khôi phục bằng `Branch.Status = 1`.
- Không tự thay đổi CompanyId, TypeTram hoặc dữ liệu khác.
- Nếu Code hoặc Username đang bị trạm active khác sử dụng, trả `409 Conflict`.

## 9. Status Code

- `200`: đọc, sửa, xóa mềm hoặc khôi phục thành công.
- `201`: tạo trạm thành công.
- `400`: request, status, TypeTram hoặc mật khẩu không hợp lệ.
- `401`: phiên đăng nhập/User/Company không còn hiệu lực.
- `403`: thiếu quyền QLTT hoặc actor không được thực hiện thao tác.
- `404`: trạm không tồn tại hoặc nằm ngoài data scope.
- `409`: Code/Username bị trùng khi tạo, sửa hoặc khôi phục.
