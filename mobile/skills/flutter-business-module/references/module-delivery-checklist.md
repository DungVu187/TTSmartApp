# Checklist Bàn Giao Phân Hệ Mobile

## Phạm Vi

- Vertical slice đã hoàn thành trọn luồng.
- Không có placeholder hoặc TODO thay logic thật.
- Module được đăng ký đúng function và route.
- Function chưa hỗ trợ được bỏ qua an toàn.

## Kiến Trúc

- Widget không gọi HTTP trực tiếp.
- DTO, repository, state và UI nằm đúng ranh giới feature.
- Không hardcode role, token, credential hoặc URL môi trường riêng.
- Không phụ thuộc tên bảng hoặc entity backend trong UI.

## Hành Vi

- `401` xóa phiên và quay về Login.
- `403` giữ phiên và hiển thị không có quyền.
- Route guard chặn mở module không được cấp quyền.
- Dữ liệu hiển thị rõ phạm vi toàn công ty hoặc trạm hiện tại.
- Không cho phép truy cập chéo trạm chỉ bằng cách thay đổi tham số phía mobile.
- Loading, empty, error, retry và thao tác lặp được xử lý.
- Điều hướng quay lại không làm mất state ngoài dự kiến.

## Xác Minh

- Code đã format.
- `flutter analyze` thành công.
- Test liên quan thành công.
- JSON mẫu thật parse đúng.
- Build nền tảng liên quan thành công hoặc đã ghi rõ lý do chưa chạy.
- Nghiệp vụ xác nhận, giả định và phụ thuộc backend được báo cáo.
