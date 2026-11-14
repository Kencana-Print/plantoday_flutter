import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

import 'widgets/web_update_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  runApp(
    const ProviderScope(
      child: PlanTodayApp(),
    ),
  );
}

class PlanTodayApp extends ConsumerWidget {
  const PlanTodayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PlanToday',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return WebUpdateBanner(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
