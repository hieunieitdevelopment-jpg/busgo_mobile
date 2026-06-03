# BusGo Mobile — Product

## Mục đích sản phẩm

BusGo Mobile là ứng dụng đồng hành dành cho hành khách của hệ thống đặt vé xe khách
**BusGo**. App đặt mục tiêu cung cấp trải nghiệm đặt vé liền mạch trên thiết bị di
động, đồng bộ 100% dữ liệu và logic với phiên bản Web (React) hiện có.

App phục vụ người dùng cuối (B2C). Quản trị nhà xe, tài xế, soát vé sử dụng các
ứng dụng riêng — KHÔNG nằm trong phạm vi repo này.

## Đối tượng người dùng

- **Khách lẻ**: tìm chuyến, đặt vé một chiều/khứ hồi, thanh toán online hoặc tiền mặt.
- **Khách quen**: lưu mã giảm giá, xem lịch sử vé, đánh giá nhà xe, quản lý hồ sơ.
- **Khách vãng lai**: duyệt nhà xe + tuyến phổ biến + khuyến mãi mà không cần đăng nhập.

Khách hàng kỳ vọng:
- UI tiếng Việt 100%, theo phong cách hiện đại của Vexere/Futa Bus Lines.
- Thao tác đặt vé < 2 phút.
- Thông báo về vé/chuyến đến sát thời gian thực.

## Phạm vi tính năng (đã làm + đang làm)

### Đã hoàn thành
- **Tìm kiếm chuyến**: Home với điểm đi/đến/ngày, tuyến phổ biến, top nhà xe theo rating.
- **Lựa chọn chuyến** (`SearchResults`): filter, sort theo giờ/giá/rating, card chuyến hiển thị rating thật từ server.
- **Chọn chỗ ngồi** (`SeatSelection`): điểm đón/trả động, sơ đồ ghế 2 tầng, rating read-only.
- **Thanh toán** (`BookingCheckout`): VNPay / Stripe Card / Tiền mặt; coupon động.
- **Vé của tôi** (`MyTickets`): list vé, hủy vé, đánh giá vé, sort mới nhất, tracker thanh toán tiền mặt phía client.
- **Hồ sơ** (`Profile`): cooldown 12h, OTP 6 ô, modal 3 bước đổi email/SĐT, badge 4 trạng thái.
- **Đánh giá** (`Rating`): xem đánh giá theo nhà xe, gửi đánh giá sau khi vé COMPLETED.
- **Thông báo**: chuông toàn cục, badge unread, danh sách phân loại, đọc tất cả.
- **Khuyến mãi** (`Promotions`): list mã giảm giá, chi tiết.

### Đang làm / chưa có
- Stripe SDK mobile (luồng AddCard / SetupIntent thực sự — hiện chỉ stub).
- Push notification thời gian thực (FCM).
- Trang Coupons & Payment Methods riêng theo prompt Profile (Phase B & D).

## Nguyên tắc trải nghiệm (UX principles)

1. **Đồng bộ với Web client**: payload, status enum, naming theo backend Swagger; KHÔNG đặt thuật ngữ riêng.
2. **Tiếng Việt là mặc định**: mọi label, message, snackbar viết tiếng Việt rõ ràng, không lẫn tiếng Anh kỹ thuật.
3. **Đồng nhất tone xanh BusGo**: gradient `#006e1c → #4caf50` cho header/button/active state. Cam, đỏ chỉ dùng cho CTA cảnh báo (hủy vé, thất bại).
4. **Phản hồi tức thì**: optimistic update (đánh dấu đọc, chọn ghế...), gọi API ngầm, lỗi catch silent với fallback rõ ràng.
5. **Bảo vệ thao tác hiếm muộn**: cooldown, confirm modal, validate client-side trước khi gọi API.
6. **Không hiển thị thông tin thừa**: form thẻ chỉ hiện khi chọn "Thẻ", QR/extra info ẩn khi không cần.

## Dữ liệu nhạy cảm

- **Token JWT** lưu trong `SharedPreferences` (chấp nhận trade-off cho tốc độ phát triển; chuyển sang `flutter_secure_storage` khi đóng gói production).
- **PII** (email, phone) chỉ hiển thị theo yêu cầu của user; không log ra console.
- **Card data**: KHÔNG lưu raw PAN. Dùng Stripe SetupIntent ở phase tiếp.

## Tích hợp ngoài

| Tích hợp | Mục đích | Trạng thái |
|----------|----------|-----------|
| Backend BusGo (`my-server.serveminecraft.net`) | Nguồn dữ liệu chính | Đã kết nối qua Dio |
| VNPay | Thanh toán online | Đã có (mở URL) |
| Stripe | Thanh toán thẻ quốc tế | Đã có (web URL); SDK mobile: phase tiếp |
| FCM | Push notification | Chưa làm |

## Định hướng phiên bản

- **v1.0** (hiện tại): hoàn thành luồng đặt-vé-đến-đánh-giá end-to-end trên Chrome/Android/iOS Flutter.
- **v1.1**: Stripe SDK mobile, FCM, Coupons & Payment Methods page.
- **v1.2**: vé khứ hồi, share vé bạn bè, multi-language.
