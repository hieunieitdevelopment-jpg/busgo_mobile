# BusGo Mobile — Project Structure

## Nguyên tắc tổ chức

- **Feature-first**: mỗi tính năng là 1 thư mục con của `lib/features/`. Trong feature, tách
  `data/` (API + DTO + tracker) và `presentation/` (pages + widgets + providers + utils).
- **Shared code dùng chung**: đặt trong `lib/core/` (api client, theme, constants, routes).
- **Không phụ thuộc chéo theo chiều ngang giữa features**: feature A muốn dùng dữ liệu của
  feature B → import qua provider/service công khai của B, KHÔNG `import` widget private.

## Thư mục cấp 1

```
busgo_mobile/
├── lib/
│   ├── core/               ← code dùng chung toàn app
│   ├── features/           ← các feature theo domain
│   └── main.dart           ← entry point + MultiProvider
├── test/                   ← unit tests
├── assets/                 ← icon + image
├── android/ ios/ web/ …    ← Flutter platform shells (giữ nguyên)
├── .kiro/
│   ├── steering/           ← project memory (file này, product.md, tech.md)
│   └── specs/              ← spec từng feature (Kiro workflow)
├── pubspec.yaml
├── analysis_options.yaml
└── AGENTS.md               ← rules cho AI agent
```

## Bố cục `lib/core/`

```
core/
├── api/
│   ├── api_client.dart           ← Dio singleton + interceptor
│   ├── notification_service.dart ← /auth/notification
│   ├── public_service.dart       ← /promotions, /companies, /trip-schedules
│   └── rating_service.dart       ← /customer/ticket/rating, /customer/trip-schedule/rating
├── constants/
│   └── app_colors.dart
├── routes/
│   └── app_routes.dart           ← GoRouter trung tâm
└── theme/
    └── app_theme.dart
```

**Quy ước**:
- `api/` — service KHÔNG phụ thuộc UI / state. Trả `Response` hoặc DTO thuần.
- `constants/` — giá trị bất biến (màu fallback, danh sách tỉnh thành...).
- `theme/` — `ThemeData` toàn app + style preset.
- `routes/` — chỉ import màn hình, KHÔNG chứa logic nghiệp vụ.

## Bố cục `lib/features/<feature>/`

Mỗi feature theo skeleton:

```
features/<feature>/
├── data/
│   ├── <feature>_service.dart        ← gọi API qua ApiClient (nếu cần riêng)
│   └── <feature>_*_tracker.dart      ← tracker SharedPreferences (nếu cần)
└── presentation/
    ├── pages/
    │   └── <feature>_page.dart       ← màn hình chính
    ├── widgets/
    │   └── *.dart                    ← widget riêng feature
    ├── providers/
    │   └── <feature>_provider.dart   ← ChangeNotifier
    └── utils/
        └── *.dart                    ← helper thuần (validators, formatters)
```

**Lưu ý**:
- Feature đơn giản chỉ dùng provider/service trong `core/api/` thì không cần `data/`. Ví dụ `notifications`, `rating`.
- KHÔNG đặt page trong `widgets/`. Page là route entry, widget là khối UI tái sử dụng trong page đó.

## Bố cục features hiện tại

| Feature | Có data? | Có providers? | Ghi chú |
|---------|----------|---------------|---------|
| `auth` | `data/auth_service.dart` | `auth_provider.dart` | Sign in/up + sendOtp + verifyContact + updateContact |
| `booking` | `data/booking_service.dart` | `booking_provider.dart` | Tìm chuyến, prepare, payment trigger |
| `home` | – | – | Dùng PublicService + BookingProvider + RatingService |
| `notifications` | – | `notification_provider.dart` | Provider toàn cục cho chuông + danh sách |
| `payment` | – | `payment_provider.dart` | Stripe stub (sẽ refactor phase Stripe SDK) |
| `profile` | – | – | Dùng AuthProvider; có `utils/profile_validators.dart`, `widgets/otp_input.dart`, `widgets/update_contact_modal.dart` |
| `promotions` | – | – | Dùng PublicService |
| `rating` | – | – | UI thuần, gọi `core/api/rating_service.dart` |
| `ticket` | `data/ticket_service.dart`, `data/cash_tickets_tracker.dart` | `ticket_provider.dart` | List vé, cancel, hủy, đánh giá |

## Quy ước đặt tên file

- Page: `<feature>_page.dart` hoặc `<feature>_<sub>_page.dart`.
- Widget: tên rõ chức năng + suffix loại (`_modal`, `_card`, `_badge`, `_input`).
- Provider: `<feature>_provider.dart` (singular). Class `<Feature>Provider`.
- Service: `<feature>_service.dart`. Class `<Feature>Service`.
- Tracker SharedPreferences: `<purpose>_tracker.dart` (vd `cash_tickets_tracker.dart`).

## Quy ước import paths

- Trong cùng feature: `import 'package:busgo_mobile/features/<feature>/...'`. KHÔNG dùng relative `../../`.
- Cross-feature qua presentation: chỉ được import provider hoặc widget public của feature khác. Cấm import file thuộc `data/` của feature khác.
- Asset: chỉ tham chiếu đường dẫn trong `assets/`, đã khai báo trong `pubspec.yaml`.

## Vị trí test

```
test/
├── rating_service_test.dart       ← parse JSON + mapping avg rating
├── profile_validators_test.dart   ← regex + cooldown 12h calculator
└── widget_test.dart               ← (placeholder Flutter mặc định)
```

**Quy ước**:
- 1 file test = 1 module logic.
- Tên file: `<thing>_test.dart`.
- Group `tiếng Việt rõ nghĩa`: `group('ProfileValidators.isValidEmail', () {...})`.

## Vị trí spec & steering

- **Steering chung** (file này, `product.md`, `tech.md`): `.kiro/steering/`.
- **Spec từng feature**: `.kiro/specs/<feature>/` (mỗi feature có `requirements.md`, `design.md`, `tasks.md`).
- **Custom steering** (auto-load theo file pattern): `.kiro/steering/<custom>.md` với front-matter `inclusion: fileMatch`.

## Khi thêm feature mới

1. Tạo thư mục `lib/features/<new>/`.
2. Quyết định có cần `data/` hay không (chỉ cần khi feature có service/tracker riêng).
3. Tạo `presentation/pages/<new>_page.dart` + đăng ký route trong `lib/core/routes/app_routes.dart`.
4. Nếu có state → tạo `presentation/providers/<new>_provider.dart` + đăng ký vào `MultiProvider` ở `main.dart`.
5. Cập nhật bảng features trong file này nếu là feature đáng kể.
6. Tuân color tokens và import order trong `tech.md`.

## Khi refactor

- Đổi tên symbol → dùng IDE rename (cập nhật cross-file).
- Di chuyển file → kiểm tra import của feature khác. Cấm break public path mà không update tất cả call site.
- Xóa code chết → confirm bằng grep `<symbol>` trên toàn `lib/` để chắc không còn ref.
