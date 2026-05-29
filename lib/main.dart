import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/booking/presentation/providers/booking_provider.dart';
import 'package:busgo_mobile/features/ticket/presentation/providers/ticket_provider.dart';
import 'package:busgo_mobile/features/payment/presentation/providers/payment_provider.dart';
import 'package:busgo_mobile/features/notifications/presentation/providers/notification_provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BusGoApp());
}

class BusGoApp extends StatelessWidget {
  const BusGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: 'BusGo Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRoutes.router,
      ),
    );
  }
}
