# RBAC API Contract

Contract chính thức cho Flutter của phân hệ User + RBAC.

## 1. Phạm vi

Backend dùng năm bảng SQL Server hiện có: User, Role, UserRole, Function và FunctionRole. Database phát triển là TTSmartMobile_Dev; dangnhap.net chỉ dùng đối chiếu read-only.

ID trong API là số nguyên theo khóa identity của database. JSON dùng camelCase. Không trả entity EF Core trực tiếp.

## 2. Authentication

### POST /api/auth/login

Request:

~~~json
{
  "userName": "ten-dang-nhap",
  "password": "mat-khau"
}
~~~

Login chỉ thành công khi User.Status = 1 và mật khẩu khớp công thức legacy của website: `MD5(KeyLock + RegEmail + UserId + MD5(mật khẩu gốc))`. Mobile gửi mật khẩu gốc qua HTTPS; backend tự thực hiện cả hai lớp băm, Flutter không gửi MD5. Lỗi username sai và mật khẩu sai dùng cùng một thông báo. JWT signing key không nằm trong response hoặc source code.

Response gồm accessToken, expiresAtUtc, user, roles, functions và roleFunctions.

### GET /api/auth/me

Yêu cầu Bearer token. Backend đọc lại User, UserRole, Role, FunctionRole và Function ở mỗi request; không tin quyền cũ trong JWT.

Nếu User bị khóa hoặc Role/FunctionRole bị thay đổi, request kế tiếp áp dụng trạng thái mới.

Danh sách `functions` chứa cả Function cha cần thiết để dựng cây menu. Function cha chỉ dùng làm container có thể có `activeKey = "000000000"` trong khi Function con có quyền thực tế.

### POST /api/auth/logout

Yêu cầu Bearer token hợp lệ. Response thành công là 204 No Content.

Backend ghi thời điểm đăng xuất vào User.TokenSince. Mọi JWT của tài khoản được phát hành trước hoặc bằng mốc này bị từ chối ở request tiếp theo với HTTP 401 và code session_revoked. Cơ chế hiện tại đăng xuất toàn bộ phiên của cùng tài khoản vì database chỉ có một mốc TokenSince dùng chung.

Flutter phải gọi endpoint logout trước, sau đó luôn xóa accessToken khỏi secure storage và chuyển về màn hình đăng nhập. Không gửi access token trong body.

### POST /api/auth/change-password

Request:

~~~json
{
  "currentPassword": "mat-khau-cu",
  "newPassword": "mat-khau-moi"
}
~~~

Đổi mật khẩu yêu cầu mật khẩu hiện tại. Reset mật khẩu quản trị dùng endpoint quản trị user. Cả đổi và reset mật khẩu đều tạo lại hash từ `KeyLock`, `RegEmail`, `UserId` hiện tại của tài khoản và cập nhật TokenSince để JWT cũ bị vô hiệu ngay.

## 3. ActiveKey

ActiveKey luôn là chuỗi đúng 9 ký tự, mỗi ký tự là 0 hoặc 1:

| Vị trí | Quyền |
|---:|---|
| 0 | Xem |
| 1 | Tạo mới |
| 2 | Cập nhật |
| 3 | Xóa |
| 4 | Nhập |
| 5 | Xuất |
| 6 | In |
| 7 | Khác |
| 8 | D.Sách |

111111111 là đầy đủ. Checkbox Đầy đủ trên mobile chỉ là trạng thái tổng hợp, không phải bit thứ 10.

Khi user có nhiều Role, quyền Function được hợp nhất bằng OR từng vị trí. roleFunctions vẫn trả từng assignment nguồn để màn hình quản trị đối chiếu.

Ví dụ:

~~~text
100000000 OR 010000000 = 110000000
~~~

ActiveKey null, sai độ dài hoặc có ký tự khác 0/1 không cấp quyền.

## 4. User

| Method | Endpoint | Quyền |
|---|---|---|
| GET | /api/users | QLND - D.Sách |
| GET | /api/users/{id} | QLND - Xem |
| POST | /api/users | QLND - Tạo mới |
| PUT | /api/users/{id} | QLND - Cập nhật |
| PUT | /api/users/{id}/status | QLND - Cập nhật |
| PUT | /api/users/{id}/roles | QLND - Cập nhật |
| POST | /api/users/{id}/reset-password | QLND - Cập nhật |
| DELETE | /api/users/{id} | QLND - Xóa |

### GET /api/users

Query hỗ trợ pageNumber, pageSize, search, status và roleId. Search áp dụng cho username, fullName, email, code và phone.

- ADMIN được đọc toàn bộ người dùng trong hệ thống.
- Tài khoản có CompanyId chỉ nhận người dùng cùng CompanyId.
- Tài khoản không phải ADMIN nhưng chưa có CompanyId chỉ nhận chính tài khoản đó; backend không mở rộng thành toàn hệ thống.
- Truy cập chi tiết hoặc thao tác User thuộc công ty khác trả 404 để không làm lộ sự tồn tại của dữ liệu ngoài phạm vi.

### POST /api/users

~~~json
{
  "userName": "nv001",
  "fullName": "Nguyen Van A",
  "password": "Password@123",
  "email": "a@example.com",
  "code": "NV001",
  "phone": "0900000000",
  "companyId": 1,
  "departmentId": 2,
  "positionId": 3,
  "unitId": 4,
  "roleIds": [3]
}
~~~

Backend tự đặt Status = 1, thời gian tạo và audit user. RoleIds phải trỏ tới Role đang hiệu lực.

- ADMIN có thể chỉ định CompanyId theo request.
- Tài khoản công ty luôn tạo/cập nhật User trong CompanyId của chính mình; gửi CompanyId khác bị trả 403.
- Tài khoản không phải ADMIN phải gán đúng một Role và không được gán Role ADMIN hoặc CONGTY.
- `Company.CountUser` là giới hạn số tài khoản con đang hiệu lực của công ty. Backend đếm User cùng `CompanyId`, có `Status = 1`, và không tính User đang có Role hiệu lực `ADMIN` hoặc `CONGTY`.
- Khi số tài khoản con đang hiệu lực đã bằng hoặc vượt `Company.CountUser`, tài khoản không phải ADMIN tạo User mới nhận `409 Conflict`. ADMIN được phép tạo vượt giới hạn này.
- User chuyển sang `Status = 99` giải phóng một suất. Khi khôi phục User về `Status = 1`, tài khoản không phải ADMIN cũng phải còn quota; nếu đã đủ quota thì nhận `409 Conflict` và User vẫn giữ trạng thái cũ.
- ADMIN được phép giảm `Company.CountUser` xuống thấp hơn số tài khoản con đang hiệu lực. Các tài khoản hiện tại không bị xóa hoặc khóa; tài khoản công ty chỉ có thể tạo/khôi phục thêm khi số đang hiệu lực nhỏ hơn quota mới.
- Các endpoint sửa trạng thái, vai trò, reset mật khẩu và xóa cũng kiểm tra CompanyId ở backend, không phụ thuộc việc mobile ẩn nút.
- Chủ doanh nghiệp không được xóa tài khoản ADMIN hoặc tài khoản CONGTY ngang cấp.

### PUT /api/users/{id}/roles

Payload thay thế toàn bộ danh sách Role hiệu lực:

~~~json
{
  "roleIds": [3, 4]
}
~~~

Bản ghi UserRole không còn được chọn được chuyển `Status = 99`. Nếu assignment xóa mềm đã tồn tại thì backend khôi phục dòng đó; chỉ tạo dòng mới khi chưa có bản ghi phù hợp. Toàn bộ thay đổi chạy trong transaction.

### PUT /api/users/{id}/status

~~~json
{
  "isActive": false
}
~~~

User bị khóa không thể login và token cũ bị từ chối ở request tiếp theo. Không được tự khóa tài khoản đang đăng nhập. Khi `isActive = true`, backend kiểm tra lại quota nếu User được khôi phục là tài khoản con và actor không phải ADMIN.

### User response

User response có thông tin hồ sơ, trạng thái và roles. Không bao giờ có Password, KeyLock hoặc password hash.

## 5. Role

| Method | Endpoint | Quyền |
|---|---|---|
| GET | /api/roles | QLQ - D.Sách |
| GET | /api/roles/{id} | QLQ - Xem |
| GET | /api/roles/{id}/function-matrix | QLQ - Xem |
| POST | /api/roles | QLQ - Tạo mới |
| PUT | /api/roles/{id} | QLQ - Cập nhật |
| PUT | /api/roles/{id}/status | QLQ - Cập nhật |
| PUT | /api/roles/{id}/functions | QLQ - Cập nhật |
| PUT | /api/roles/{id}/functions/{functionId}/active-key | QLQ - Cập nhật |
| DELETE | /api/roles/{id}/functions/{functionId} | QLQ - Xóa |
| DELETE | /api/roles/{id} | QLQ - Xóa |

### POST /api/roles

~~~json
{
  "code": "QUANLYTRAM",
  "name": "Quản lý trạm",
  "note": "Vai trò quản lý dữ liệu trạm",
  "levelRole": 1
}
~~~

Code và Name của Role đang hiệu lực không được trùng.

### PUT /api/roles/{id}/functions

Payload thay thế toàn bộ ma trận FunctionRole hiệu lực của Role:

~~~json
{
  "functions": [
    {
      "functionId": 3060,
      "activeKey": "111111111"
    },
    {
      "functionId": 3063,
      "activeKey": "100000000"
    }
  ]
}
~~~

Backend ghi Type = 2, TargetId = RoleId. Bản ghi cũ không còn trong payload được chuyển Status = 99; bản ghi cũ bị xóa mềm được khôi phục hoặc cập nhật, không tạo assignment trùng cho cùng Role và Function.

### GET /api/roles/{id}/function-matrix

Trả toàn bộ Function hiệu lực để mobile dựng màn hình checkbox. Function chưa được gán vẫn xuất hiện với `isAssigned = false` và `activeKey = "000000000"`.

~~~json
[
  {
    "functionId": 4,
    "parentFunctionId": 1,
    "code": "QLND",
    "name": "Người dùng",
    "url": "user",
    "location": 49,
    "icon": null,
    "functionRoleId": 3163,
    "isAssigned": true,
    "activeKey": "111111111",
    "permissions": {
      "view": true,
      "create": true,
      "update": true,
      "delete": true,
      "import": true,
      "export": true,
      "print": true,
      "other": true,
      "dSach": true,
      "full": true
    }
  }
]
~~~

### DELETE /api/roles/{id}/functions/{functionId}

Bỏ assignment bằng xóa mềm: mọi FunctionRole hiệu lực trùng Role/Function/Type được chuyển `Status = 99`. Backend không cho thao tác làm mất đường quản trị Role cuối cùng.

## 6. Function

| Method | Endpoint | Quyền |
|---|---|---|
| GET | /api/functions | QLCN - D.Sách |
| GET | /api/functions/tree | QLCN - D.Sách |
| GET | /api/functions/{id} | QLCN - Xem |
| POST | /api/functions | QLCN - Tạo mới |
| PUT | /api/functions/{id} | QLCN - Cập nhật |
| PUT | /api/functions/{id}/status | QLCN - Cập nhật |
| DELETE | /api/functions/{id} | QLCN - Xóa |

GET /api/functions trả danh sách phẳng có parentFunctionId để mobile dựng cây. FunctionParentId = 0 trong database được trả thành null.

GET /api/functions/tree trả cấu trúc lồng nhau với field `children`; hỗ trợ cùng query `search` và `status` như danh sách phẳng.

Không thể xóa function đang có function con hiệu lực. Xóa function là xóa mềm và các FunctionRole hiệu lực liên quan được chuyển Status = 99.

## 7. Status và lỗi

- Status = 1: hiệu lực.
- Status = 99: ngừng hiệu lực hoặc xóa mềm.
- Khi không truyền `status`, các endpoint danh sách User, Role và Function mặc định chỉ lấy `Status = 1`.
- Muốn xem dữ liệu ngừng hiệu lực, truyền `status=99`.
- `status` chỉ nhận `1` hoặc `99`.
- Payload đổi trạng thái bắt buộc có `isActive`; body rỗng trả `400`, không tự hiểu là `false`.
- 400: body/query không hợp lệ.
- 401: chưa login, token sai/hết hạn hoặc user đã bị khóa.
- 403: đã login nhưng thiếu bit quyền endpoint.
- 404: không tìm thấy resource.
- 409: trùng mã/tên, vòng lặp function, xung đột xóa, vi phạm bảo toàn quản trị hoặc công ty đã dùng đủ quota tài khoản con.
- 500: lỗi hệ thống; response không lộ SQL hoặc stack trace.

Lỗi dùng `ProblemDetails` hoặc `ValidationProblemDetails`:

~~~json
{
  "type": "about:blank",
  "title": "Dữ liệu không hợp lệ",
  "status": 400,
  "detail": "Status chỉ nhận giá trị 1 hoặc 99.",
  "instance": "/api/users",
  "traceId": "..."
}
~~~

Danh sách phân trang dùng cấu trúc:

~~~json
{
  "items": [],
  "pageNumber": 1,
  "pageSize": 20,
  "totalCount": 0,
  "totalPages": 0
}
~~~

Các field thời gian có hậu tố `Utc` dùng ISO 8601; field nullable được trả `null`, không dùng chuỗi rỗng thay cho null.

## 8. Luồng mobile

1. Gọi login và lưu accessToken bằng secure storage.
2. Gọi /api/auth/me sau login hoặc khi mở lại app.
3. Dùng `functions` để dựng menu được phép truy cập; giữ Function cha có ActiveKey rỗng quyền nếu nó chứa Function con được cấp quyền.
4. Màn hình cấu hình Role gọi `GET /api/roles/{id}/function-matrix`, sau đó dùng `permissions` hoặc `activeKey` để dựng checkbox 9 quyền.
5. Không chỉ ẩn nút ở mobile; luôn xử lý 401/403 từ backend.
6. Sau khi cập nhật quyền, gọi lại /api/auth/me để nhận ma trận mới.
7. Khi đăng xuất, gọi POST /api/auth/logout rồi xóa token khỏi secure storage; nếu nhận code session_revoked thì xóa token và yêu cầu đăng nhập lại.

Chi tiết function code và quyền endpoint nằm trong docs/RBAC_PERMISSION_MATRIX.md.

## 9. Cấu hình

Connection string giữ nguyên khóa ConnectionStrings:AuthConnection. Local Development trỏ tới TTSmartMobile_Dev. JWT signing key phải đặt bằng user-secrets hoặc biến môi trường Jwt__SigningKey.

AuthDatabase:PasswordWriteMode nhận Md5Utf8 hoặc Md5Unicode. MD5 chỉ được dùng để tương thích database web hiện tại, không dùng cho thiết kế mật khẩu mới độc lập.
