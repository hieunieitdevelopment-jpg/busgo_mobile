# BusGo Mobile — Tech Stack

## Stack tổng quan

- **Framework**: Flutter 3+ (Dart `>=3.0.0 <4.0.0`)
- **Phạm vi build**: web (Chrome dev), Android, iOS, Windows, macOS, Linux (multi-platform mặc định)
- **Architecture pattern**: Feature-first + presentation/data tách lớp; KHÔNG dùng clean-architecture nặng nề.

## Dependencies cố định (KHÔNG đổi nếu không có lý do mạnh)

| Package | Version | Mục đích |
|---------|---------|----------|
| `provider` | `^6.1.2` | State management (ChangeNotifier) |
| `go_router` | `^13.2.0` | Routing khai báo + deep link |
| `dio` | `^5.4.3` | HTTP client + interceptor |
| `shared_preferences` | `^2.2.3` | Cache local (token, user, deleted_tickets, cash_paid_*) |
| `url_launcher` | `^6.3.1` | Mở VNPay/Stripe/external URL |
| `google_fonts` | `^6.2.0` | Be Vietnam Pro |
| `flutter_svg` | `^2.0.10` | Asset SVG |
| `intl` | `^0.19.0` | Format ngày, tiền |
| `flutter_lints` | `^3.0.0` (dev) | Lint chuẩn |

**Quy ước thêm dependency mới**: PR mô tả lý do, trade-off, alternative đã loại; cập nhật vào `tech.md` này.

## Pattern bắt buộc

### State management
- Mỗi feature có 1 hoặc nhiều `ChangeNotifierProvider` đăng ký ở `main.dart` (`MultiProvider`).
- Provider hiện tại: `AuthProvider`, `BookingProvider`, `TicketProvider`, `PaymentProvider`, `NotificationProvider`.
- KHÔNG dùng GetX, Riverpod, Bloc — nhất quán với code base hiện tại.
- Provider phải `notifyListeners()` sau mọi mutation; UI dùng `Consumer` hoặc `Provider.of(context)` listen.

### HTTP / API client
- Singleton `ApiClient` trong `lib/core/api/api_client.dart`.
- `Dio` được cấu hình với:
  - `baseUrl: https://my-server.serveminecraft.net`
  - `connectTimeout: 15s`, `receiveTimeout: 15s`
  - Header `Content-Type: application/json`, `Accept: application/json`
- `InterceptorsWrapper`:
  - Tự đính kèm `Authorization: Bearer <token>` (trừ public endpoints `/auth/send-otp`, `/auth/sign-in`, `/customer/sign-in`, `/customer/sign-up`, `/auth/reset-password`).
  - 401 → xóa token + user, ném `DioException` đã dịch tiếng Việt.
  - Translator lỗi tiếng Việt thống nhất trong `_translateError`.
- Mỗi feature có file `*_service.dart` riêng dùng `ApiClient().dio`. KHÔNG khởi tạo Dio mới.

### Routing
- File trung tâm: `lib/core/routes/app_routes.dart`.
- Dùng `GoRouter`. Mọi navigation gọi `context.go()` / `context.push()`. Không dùng `Navigator.pushNamed`.
- Route paths viết kebab-case: `/my-tickets`, `/seat-selection`, `/boarding-pass`.

### Storage
- **Token + user**: `SharedPreferences` keys `token`, `user`. Quy ước Auth ghi đè cả 2 khi `signIn` / `updateContact` thành công.
- **Cache feature-specific**: prefix `busgo_*` (vd `cash_paid_ticket_ids`, `cash_paid_booking_ids`, `busgo_deleted_tickets`, `busgo_ticket_expire_<id>`).
- KHÔNG đặt cache vô danh; mọi key phải có comment mô tả mục đích.

### UI / Design system
- Color tokens (định nghĩa trong từng file dùng `static const`):
  - `_primary = Color(0xff006e1c)`
  - `_primaryLight = Color(0xff4caf50)`
  - `_primaryGradient = LinearGradient([_primary, _primaryLight], topLeft → bottomRight)`
- Background mặc định trang: `Color(0xfff5f7f5)`.
- BorderRadius chuẩn: card `16`, button `12-14`, chip `20-22`.
- Shadow chuẩn: `Colors.black.withOpacity(0.05)` blur `10-12` offset `(0, 4)`.
- Font: Be Vietnam Pro qua `google_fonts`. Weight chính: `600 / 700 / 800 / 900`.
- KHÔNG dùng `Material` color khác (`Colors.green`, `Colors.lightGreen`) trong CTA chính.

### Error handling
- Network: bắt `DioException`, lấy `e.response?.data?['message']` hoặc `e.error`. Fallback "Đã xảy ra lỗi. Vui lòng thử lại."
- Notification side-effect: bọc `try/catch` riêng, KHÔNG được fail flow chính (ví dụ tạo notification sau đặt vé).
- Validation client trước khi gọi API; KHÔNG đẩy lỗi 400 về server xử lý.
- Toast/SnackBar cho mọi success/error nhìn thấy được. KHÔNG dùng `AlertDialog` cho thông báo ngắn.

### Async patterns
- `Future<bool>` cho action có boolean kết quả (thành công/thất bại). Provider lưu `_errorMessage` cho UI đọc.
- Tránh swallow exception với `catch (_) {}` trừ side-effect không quan trọng (notification, log).
- Dùng `if (!mounted) return;` sau mọi `await` trước khi gọi `setState` hoặc dùng `context`.

### Testing
- Unit tests trong `test/` cho: validators, parsers, mapping rating, cooldown calculator.
- Test name viết tiếng Việt rõ nghĩa: `test('Email hợp lệ', () {...})`.
- Không cần widget test cho UI hiện tại; chỉ test logic thuần.
- Chạy: `flutter test test/<file>.dart`.

## Quy ước code

### Tên file & class
- File: `snake_case.dart` (vd `notification_service.dart`).
- Class: `PascalCase` (`NotificationProvider`).
- Function: `camelCase`.
- Private (`_`) cho mọi method/field không export.

### Comment & docstring
- Tiếng Việt, ngắn gọn, đặt tại nơi cần giải thích **lý do** (không phải lặp lại what).
- Public API class có docstring `///` mô tả mục đích + edge case (vd `RatingService`, `CashTicketsTracker`).

### Import order
1. `dart:` (vd `dart:async`)
2. `package:flutter/...`
3. `package:` third-party
4. `package:busgo_mobile/...` (relative)

### Lints
- Tuân `flutter_lints`. Cảnh báo `info` không bắt buộc fix, nhưng PR mới KHÔNG được introduce thêm warning/error.
- `prefer_const_constructors`: dùng `const` mọi nơi có thể.
- KHÔNG `print` trong code production (đã có một số chỗ legacy, không thêm mới).

## Build & dev commands

```cmd
:: Lấy dependencies
flutter pub get

:: Phân tích code
flutter analyze

:: Phân tích chỉ một module
flutter analyze lib/features/profile

:: Test một file
flutter test test/profile_validators_test.dart

:: Chạy dev trên Chrome
flutter run -d chrome

:: Build APK release
flutter build apk --release

:: Build web release
flutter build web --release
```

## Performance & N+1

- **List + per-item fetch**: bắt buộc gom `uniqueIds` rồi gọi `Future.wait`. Tham khảo `RatingService.getSummariesParallel`.
- **Cache 60s** cho dữ liệu ít thay đổi (rating). Key cache phải xác định: `<entity>|<param1>|<param2>`.
- **Optimistic UI**: cập nhật state trước, gọi API sau (vd mark-as-read).

## Security checklist

- [ ] Mỗi service có header `Authorization` qua interceptor.
- [ ] Không log token/PII.
- [ ] Không nhúng API key trong source (Stripe/maps... → dùng `--dart-define`).
- [ ] Validate client-side: regex email/phone/OTP trong `ProfileValidators`.
- [ ] Confirm modal cho mọi delete (xóa thẻ, hủy vé).
