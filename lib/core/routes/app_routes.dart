import 'package:go_router/go_router.dart';

import 'package:busgo_mobile/features/home/presentation/pages/home_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/search_results_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/seat_selection_page.dart';
import 'package:busgo_mobile/features/booking/presentation/pages/booking_checkout_page.dart';
import 'package:busgo_mobile/features/ticket/presentation/pages/boarding_pass_page.dart';
import 'package:busgo_mobile/features/ticket/presentation/pages/my_tickets_page.dart';
import 'package:busgo_mobile/features/promotions/presentation/pages/promotions_page.dart';
import 'package:busgo_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:busgo_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:busgo_mobile/features/auth/presentation/pages/register_page.dart';

class AppRoutes {
  AppRoutes._();

  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
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
    ],
  );
}
