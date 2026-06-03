import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';

import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/ticket/presentation/providers/ticket_provider.dart';
import 'package:busgo_mobile/features/payment/presentation/providers/payment_provider.dart';
import 'package:busgo_mobile/features/notifications/presentation/providers/notification_provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Facebook Auth cho nền tảng Web
  if (kIsWeb) {
    await FacebookAuth.i.webAndDesktopInitialize(
      appId: "1920728485259212",
      cookie: true,
      xfbml: true,
      version: "v13.0",
    );
  }

  // Load trạng thái onboarding trước khi app khởi động
  await AppRoutes.loadOnboardingStatus();

  runApp(const BusGoApp());
}

class BusGoApp extends StatelessWidget {
  const BusGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tạo AuthProvider trước để truyền vào cả Router và Provider tree
    final authProvider = AuthProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: 'BusGo Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRoutes.createRouter(authProvider),
      ),
    );
  }
}
