import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:busgo_mobile/features/home/presentation/pages/home_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/search_results_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/seat_selection_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/booking_checkout_page.dart';
import 'package:busgo_mobile/features/ticket/presentation/pages/boarding_pass_page.dart';
import 'package:busgo_mobile/features/ticket/presentation/pages/my_tickets_page.dart';
import 'package:busgo_mobile/features/promotions/presentation/pages/promotions_page.dart';
import 'package:busgo_mobile/features/promotions/presentation/pages/promotion_detail_page.dart';
import 'package:busgo_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:busgo_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:busgo_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:busgo_mobile/features/notifications/presentation/pages/notifications_page.dart';
import 'package:busgo_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';

class AppRoutes {
  AppRoutes._();

  /// Các trang công khai — không cần đăng nhập
  static const _publicPaths = ['/login', '/register', '/onboarding'];

  /// Cờ lưu trạng thái đã xem onboarding hay chưa (cache trong memory)
  static bool? _onboardingCompleted;

  /// Load trạng thái onboarding từ SharedPreferences (gọi 1 lần khi app khởi động)
  /// Để phục vụ kiểm thử và đảm bảo luôn đi qua Onboarding khi khởi chạy: reset cờ này về false.
  static Future<void> loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed'); // Xóa cờ cũ
    _onboardingCompleted = false; // Mặc định luôn hiện onboarding khi mở app
  }

  /// Cập nhật động trạng thái hoàn thành onboarding
  static void setOnboardingCompleted(bool value) {
    _onboardingCompleted = value;
  }

  /// Tạo router với redirect guard:
  /// 1. Chưa xem onboarding → /onboarding
  /// 2. Đã xem onboarding + chưa login → /login
  /// 3. Đã login → cho vào app bình thường
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/onboarding',
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final currentPath = state.matchedLocation;

        // ── Bước 1: Kiểm tra Onboarding ──
        final onboardingDone = _onboardingCompleted ?? false;

        if (!onboardingDone && currentPath != '/onboarding') {
          return '/onboarding';
        }

        if (onboardingDone && currentPath == '/onboarding') {
          // Đã xem onboarding rồi → chuyển sang login hoặc home
          return isLoggedIn ? '/' : '/login';
        }

        // ── Bước 2: Kiểm tra Auth ──
        final isGoingToPublicPage = _publicPaths.contains(currentPath);

        // Chưa đăng nhập + đang vào trang bảo vệ → redirect về login
        if (!isLoggedIn && !isGoingToPublicPage) {
          return '/login';
        }

        // Đã đăng nhập + đang vào login/register → redirect về home
        if (isLoggedIn && (currentPath == '/login' || currentPath == '/register')) {
          return '/';
        }

        return null;
      },
      routes: [
        // 0. Onboarding (giới thiệu app)
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),

        // 1. BusGo Homepage
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        
        // 2. Search Results
        GoRoute(
          path: '/search-results',
          builder: (context, state) => const SearchResultsPage(),
        ),

        // 3. Seat Selection
        GoRoute(
          path: '/seat-selection',
          builder: (context, state) => const SeatSelectionPage(),
        ),

        // 4. Booking Checkout & Payment
        GoRoute(
          path: '/booking',
          builder: (context, state) => const BookingCheckoutPage(),
        ),

        // 5. Boarding Pass & QR Ticket
        GoRoute(
          path: '/boarding-pass',
          builder: (context, state) => const BoardingPassPage(),
        ),

        // 6. My Tickets List
        GoRoute(
          path: '/my-tickets',
          builder: (context, state) => const MyTicketsPage(),
        ),

        // 7. Promotions list
        GoRoute(
          path: '/promotions',
          builder: (context, state) => const PromotionsPage(),
        ),

        // 7b. Promotion Detail
        GoRoute(
          path: '/promotion-detail',
          builder: (context, state) {
            final promo = state.extra as Map<String, dynamic>;
            return PromotionDetailPage(promotion: promo);
          },
        ),

        // 8. User Profile Edit
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),

        // 9. Login Page
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),

        // 10. Register Page
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),

        // 11. Notifications List
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
      ],
    );
  }
}
