# API Quan Ly Cong Ty Cho Mobile

## 1. Pham Vi

- Base route: /api/companies.
- Function phan quyen: QLCT.
- ADMIN la Super Admin, bo qua ActiveKey, Company lock, han dich vu va pham vi CompanyId.
- Tai khoan khac phai co bit quyen tuong ung va chi duoc doc/thao tac Company trung User.CompanyId.
- Chi ADMIN duoc tao Company moi.

## 2. Quyen ActiveKey

| API | Bit quyen |
|---|---|
| Danh sach | D.Sach |
| Chi tiet, doc logo | Xem |
| Tao Company | Tao moi |
| Sua, khoa, han, logo, khoi phuc | Cap nhat |
| Xoa mem | Xoa |

## 3. Company Response

Vi du JSON:

    {
      "id": 15,
      "code": "CT_A",
      "name": "Cong ty A",
      "email": "contact@example.com",
      "phone": "0900000000",
      "address": "Ha Noi",
      "fax": null,
      "representative": "Nguyen Van A",
      "contactName": "Tran Van B",
      "contactEmail": "support@example.com",
      "contactPhone": "0911111111",
      "createdAtUtc": "2026-07-28T02:00:00Z",
      "updatedAtUtc": "2026-07-28T02:00:00Z",
      "userId": 1,
      "status": 1,
      "isActive": true,
      "countUser": 9,
      "active": 1,
      "isLocked": false,
      "note": null,
      "logo": "a4f92c.png",
      "expiredDate": "2027-01-01"
    }

- status = 1: hieu luc.
- status = 99: xoa mem.
- active = 0: mien phi; active = 1: tra phi.
- isLocked: khoa thu cong danh cho backend/mobile.
- expiredDate = null: khong gioi han.

## 4. Danh Sach Va Chi Tiet

### GET /api/companies

Query:

- pageNumber: mac dinh 1.
- pageSize: mac dinh 20, toi da 100.
- search: tim theo ma, ten, email, dien thoai hoac nguoi lien he.
- status: 1 hoac 99; mac dinh 1.
- isLocked: loc theo trang thai khoa.

Response la PagedResponse<CompanyResponse>, sap xep theo name sau do id.

### GET /api/companies/{id}

Tra chi tiet Company trong pham vi duoc phep.

## 5. Tao Va Sua

### POST /api/companies

Chi ADMIN. Request JSON:

    {
      "code": "CT_A",
      "name": "Cong ty A",
      "email": "contact@example.com",
      "phone": "0900000000",
      "address": "Ha Noi",
      "fax": null,
      "representative": null,
      "contactName": null,
      "contactEmail": null,
      "contactPhone": null,
      "countUser": 9,
      "active": 1,
      "note": null
    }

- Bat buoc: code, name, email, phone.
- `code` là mã công ty (CompanyCode trong nghiệp vụ) và được lưu tại `dbo.Company.Code`. Backend trim khoảng trắng đầu/cuối nhưng phân biệt chữ hoa/thường: `dacdao` và `DacDao` là hai mã khác nhau.
- Mã chỉ cần duy nhất giữa các Company `Status = 1`. Tạo hoặc đổi sang mã trùng chính xác với Company đang hoạt động trả `409 Conflict` với detail `Mã công ty đã tồn tại.`; mã của Company `Status = 99` được phép sử dụng lại.
- Nếu dữ liệu legacy có nhiều Company đang hoạt động trùng chính xác mã, backend không tự sửa/xóa và vẫn cho cập nhật bản ghi nếu giữ nguyên mã hiện tại.
- countUser >= 0; đây là quota số User con `Status = 1` cùng CompanyId, không tính Role ADMIN hoặc CONGTY.
- active chi nhan 0 hoac 1.
- Backend tu dat status = 1, isLocked = false.

Quota được kiểm tra khi tài khoản không phải ADMIN tạo hoặc khôi phục User con. Đủ quota trả `409 Conflict`; ADMIN vẫn được tạo hoặc khôi phục vượt quota. User `Status = 99` không chiếm quota.

ADMIN được phép lưu `countUser` thấp hơn số User con đang hiệu lực. Backend không tự xóa hoặc khóa User hiện tại; tài khoản công ty bị chặn tạo/khôi phục thêm cho đến khi số User con `Status = 1` nhỏ hơn quota mới.

### PUT /api/companies/{id}

Request giong tao. Khong sua status, isLocked, expiredDate, logo, PMQLXe, QLCamera hoac audit fields.

## 6. Khoa, Han Va Trang Thai

### PUT /api/companies/{id}/lock

Request: { "isLocked": true }

Sau khi khoa, moi request tiep theo bang JWT cu cua tai khoan thuoc Company bi tra 401 ngay. Thong bao khoa co code company_locked.

### PUT /api/companies/{id}/expiration

Request: { "expiredDate": "2027-01-01" }

- API nhan ngay thuan yyyy-MM-dd.
- DB luu 2026-12-31 23:59:59 theo gio Viet Nam.
- Company bi chan tu 2027-01-01 00:00:00.
- Gui null de bo gioi han.

### DELETE /api/companies/{id}

Xoa mem bang status = 99, khong xoa du lieu vat ly.

### POST /api/companies/{id}/restore

Khoi phuc status = 1; giu nguyen isLocked, expiredDate, logo va du lieu khac.

## 7. Logo

### POST /api/companies/{id}/logo

- Content type: multipart/form-data.
- Field: file.
- Cho phep: JPG, JPEG, PNG, WEBP.
- Dung luong toi da: 5 MB.
- Backend luu file vat ly trong src/TTSmart.Api/uploads/company-logos va chi luu ten file vao Company.Logo.

### GET /api/companies/{id}/logo

Tra file logo, ho tro range request. Logo legacy khong ton tai trong storage mobile se tra 404.

## 8. Ma Loi Company

| Code | Y nghia |
|---|---|
| company_inactive | Company khong con hieu luc hoac khong ton tai |
| company_locked | Company bi khoa thu cong |
| company_expired | Company da qua han theo gio Viet Nam |

- 400: validation sai.
- 401: token, user hoac Company khong con duoc phep.
- 403: thieu quyen hoac actor khong duoc phep tao Company.
- 404: khong tim thay Company trong pham vi actor hoac khong co file logo.
