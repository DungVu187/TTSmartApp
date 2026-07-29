# Đề xuất contract backend cho giao diện mobile

## Phạm vi

Các màn `home`, `orders`, `reports`, `notifications` và `settings` hiện dùng
repository mock. Widget và controller chỉ phụ thuộc abstraction nên có thể thay
bằng API repository mà không viết lại giao diện.

## Tenant và phạm vi dữ liệu

Backend cần trả riêng nhận diện tenant, quyền chức năng và phạm vi dữ liệu.

```http
GET /api/mobile/context
```

Mobile chỉ dùng phạm vi backend trả để tạo bộ lọc. Mọi endpoint vẫn phải kiểm
tra authorization chéo công ty và trạm; không tin `companyId` hoặc `stationId`
chỉ vì mobile gửi lên.

## Trang chủ

```http
GET /api/dashboard/summary?scopeType=company&scopeId=12&period=today
```

`period`: `today`, `sevenDays`, `thisMonth`. Response cần có `updatedAtUtc`,
chỉ số tổng quan, chuỗi xu hướng, trạng thái trạm và hoạt động gần đây.

Cần xác nhận công thức nghiệp vụ của “Mác bê tông trong ngày” và “Kinh doanh có
đơn trong ngày”; FE hiện chỉ dùng số liệu minh họa.

## Đơn hàng

```http
GET /api/orders?page=1&pageSize=20&search=DH-10&status=mixing&period=today&scopeType=company&scopeId=12
GET /api/orders/{id}
```

Danh sách cần phân trang ổn định và trả tối thiểu `id`, `code`, `customerName`,
`stationId`, `stationName`, `concreteGrade`, `quantity`, `deliveredQuantity`,
`scheduledAtUtc`, `status`. Chi tiết bổ sung địa chỉ giao, người liên hệ, điện
thoại, yêu cầu kỹ thuật, hình thức bơm và ghi chú. Backend cần xác nhận enum
trạng thái và quy tắc tính khối lượng đã giao.

## Báo cáo

```http
GET /api/reports/order-summary?scopeType=company&scopeId=12&period=sevenDays
```

Response cần có `updatedAtUtc`, tổng đơn, sản lượng, tỷ lệ hoàn thành, số trạm
hoạt động, chuỗi xu hướng và số liệu so sánh theo trạm. Backend cần xác nhận
timezone dùng để chia ngày và kỳ báo cáo.

## Thông báo và cài đặt

```http
GET /api/notifications?page=1&pageSize=20
```

Response cần có danh sách phân trang và `unreadCount`. FE hiện dùng empty state,
chưa triển khai push notification hoặc quyền Android/iOS. Tùy chọn bật/tắt
thông báo đang lưu trong `MemorySettingsRepository`; backend cần xác nhận đây là
cài đặt theo thiết bị, theo tài khoản hay kết hợp cả hai.

## Module bản xem trước

Các key `preview.*` chỉ là key FE tạm thời, không phải function code backend.
Trước khi nối API cần xác nhận function code, `ActiveKey`, route và data scope.
Module Hệ thống tiếp tục dùng `QLCN`, `QLQ`, `QLND` đã xác nhận.

## Lỗi

Endpoint mới ưu tiên `ProblemDetails`: `400` dữ liệu không hợp lệ, `401` hết
phiên, `403` thiếu quyền, `404` không tìm thấy, `409` xung đột và `500` lỗi
server. Không trả stack trace hoặc chi tiết SQL cho mobile.
