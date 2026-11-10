import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/achievement_model.dart';
import '../models/customer_model.dart';
import '../models/kurir_model.dart';
import '../models/permintaan_harga_model.dart';
import '../models/visit_model.dart';
import '../providers/auth_provider.dart';
import '../screens/achievement/achievement_detail_user_screen.dart';
import '../screens/achievement/achievement_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/rekap_calon_customer_screen.dart';
import '../screens/home/ganti_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/kurir/kurir_menu_screen.dart';
import '../screens/kurir/proses_pengiriman_screen.dart';
import '../screens/kurir/tambah_pengiriman_screen.dart';
import '../screens/penawaran/cari_nomor_penawaran_screen.dart';
import '../screens/penawaran/cari_perusahaan_screen.dart';
import '../screens/penawaran/cari_sales_screen.dart';
import '../screens/penawaran/penawaran_create_screen.dart';
import '../screens/penawaran/penawaran_detail_screen.dart';
import '../screens/penawaran/penawaran_list_screen.dart';
import '../screens/penawaran/penawaran_status_screen.dart';
import '../screens/penawaran/tracking_map_screen.dart';
import '../screens/penawaran/tracking_penawaran_screen.dart';
import '../screens/penawaran/tracking_spk_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_detail_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_form_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_list_screen.dart';
import '../screens/permintaan_harga/tambah_customer_screen.dart';
import '../screens/inkaso/invoice_jatuh_tempo_screen.dart';
import '../screens/potensi/laporan_potensi_screen.dart';
import '../screens/potensi/potensi_screen.dart';
import '../screens/visit/edit_visit_plan_screen.dart';
import '../screens/visit/edit_visit_screen.dart';
import '../screens/visit/rekap_visit_plan_detail_screen.dart';
import '../screens/visit/tambah_visit_plan_screen.dart';
import '../screens/visit/tambah_visit_screen.dart';
import '../screens/visit/visit_plan_screen.dart';
import '../screens/visit/visit_screen.dart';

class AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!authState.isAuthenticated) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      if (isLoggingIn || isRegistering) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        ),
      ),

      // Modul Customer
      GoRoute(
        path: '/customer',
        name: 'customer',
        builder: (context, state) => const RekapCalonCustomerScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-customer',
            builder: (context, state) =>
                const TambahCustomerPermintaanHargaScreen(),
          ),
          GoRoute(
            path: 'edit',
            name: 'edit-customer',
            builder: (context, state) {
              final customer = state.extra as CustomerModel?;
              return TambahCustomerPermintaanHargaScreen(
                initialCustomer: customer,
              );
            },
          ),
        ],
      ),

      // Modul Visit
      GoRoute(
        path: '/visit',
        name: 'visit',
        builder: (context, state) => const VisitScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-visit',
            builder: (context, state) {
              final initialCustomer = state.extra as CustomerModel?;
              return TambahVisitScreen(initialCustomer: initialCustomer);
            },
          ),
          GoRoute(
            path: 'edit',
            name: 'edit-visit',
            builder: (context, state) {
              final visit = state.extra as VisitModel;
              return EditVisitScreen(visit: visit);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/visit-plan',
        name: 'visit-plan',
        builder: (context, state) => const VisitPlanScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-visit-plan',
            builder: (context, state) {
              final initialCustomer = state.extra as CustomerModel?;
              return TambahVisitPlanScreen(initialCustomer: initialCustomer);
            },
          ),
          GoRoute(
            path: 'edit',
            name: 'edit-visit-plan',
            builder: (context, state) {
              final plan = state.extra as VisitModel;
              return EditVisitPlanScreen(plan: plan);
            },
          ),
          GoRoute(
            path: 'detail/:id',
            name: 'detail-visit-plan',
            builder: (context, state) {
              final idStr = state.pathParameters['id'] ?? '0';
              final id = int.tryParse(idStr) ?? 0;
              final canEdit = (state.extra as bool?) ?? true;
              return RekapVisitPlanDetailScreen(id: id, canEdit: canEdit);
            },
          ),
        ],
      ),

      // Modul Penawaran
      GoRoute(
        path: '/penawaran',
        name: 'penawaran',
        builder: (context, state) => const PenawaranListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'create-penawaran',
            builder: (context, state) => const PenawaranCreateScreen(),
          ),
          GoRoute(
            path: 'cari-sales',
            name: 'cari-sales',
            builder: (context, state) {
              final keyword = state.extra as String?;
              return CariSalesScreen(initialKeyword: keyword);
            },
          ),
          GoRoute(
            path: 'cari-perusahaan',
            name: 'cari-perusahaan',
            builder: (context, state) => const CariPerusahaanScreen(),
          ),
          GoRoute(
            path: 'cari-nomor',
            name: 'cari-nomor-penawaran',
            builder: (context, state) {
              final keyword = state.extra as String?;
              return CariNomorPenawaranScreen(initialKeyword: keyword);
            },
          ),
          GoRoute(
            path: ':nomor',
            name: 'penawaran-detail',
            builder: (context, state) {
              final raw = state.pathParameters['nomor'] ?? '';
              final nomor = (state.extra as String?) ?? Uri.decodeComponent(raw);
              return PenawaranDetailScreen(nomor: nomor);
            },
            routes: [
              GoRoute(
                path: 'status',
                name: 'penawaran-status',
                builder: (context, state) {
                  final raw = state.pathParameters['nomor'] ?? '';
                  final nomor = (state.extra as String?) ?? Uri.decodeComponent(raw);
                  return PenawaranStatusScreen(nomor: nomor);
                },
              ),
            ],
          ),
        ],
      ),

      // Modul Tracking
      GoRoute(
        path: '/tracking-penawaran',
        name: 'tracking-penawaran',
        builder: (context, state) {
          final extraStr = state.extra is String ? (state.extra as String).trim() : null;
          final queryStr = state.uri.queryParameters['q']?.trim();
          final search = (extraStr != null && extraStr.isNotEmpty) ? extraStr : queryStr;

          return TrackingPenawaranScreen(
            key: ValueKey('tracking-penawaran-$search'),
            initialSearch: search,
          );
        },
      ),
      GoRoute(
        path: '/tracking-map',
        name: 'tracking-map',
        builder: (context, state) {
          final extraStr = state.extra is String ? (state.extra as String).trim() : null;
          final queryStr = state.uri.queryParameters['q']?.trim();
          final search = (extraStr != null && extraStr.isNotEmpty) ? extraStr : queryStr;

          return TrackingMapScreen(
            key: ValueKey('tracking-map-$search'),
            initialSearch: search,
          );
        },
      ),
      GoRoute(
        path: '/tracking-spk',
        name: 'tracking-spk',
        builder: (context, state) => const TrackingSpkScreen(),
      ),

      // Modul Permintaan Harga
      GoRoute(
        path: '/permintaan-harga',
        name: 'permintaan-harga',
        builder: (context, state) => const PermintaanHargaListScreen(),
        routes: [
          GoRoute(
            path: 'kalkulasi',
            name: 'permintaan-harga-kalkulasi',
            builder: (context, state) => const PermintaanHargaFormScreen(),
          ),
          GoRoute(
            path: 'edit',
            name: 'permintaan-harga-edit',
            builder: (context, state) {
              final detail = state.extra as PermintaanHargaDetail?;
              return PermintaanHargaFormScreen(initialDetail: detail);
            },
          ),
          GoRoute(
            path: 'tambah-customer',
            name: 'permintaan-harga-tambah-customer',
            builder: (context, state) =>
                const TambahCustomerPermintaanHargaScreen(),
          ),

          GoRoute(
            path: ':nomor',
            name: 'permintaan-harga-detail',
            builder: (context, state) {
              final nomor = state.pathParameters['nomor'] ?? '';
              return PermintaanHargaDetailScreen(nomor: nomor);
            },
          ),
        ],
      ),

      // Modul Potensi
      GoRoute(
        path: '/potensi',
        name: 'potensi',
        builder: (context, state) => const PotensiScreen(),
      ),
      GoRoute(
        path: '/laporan-potensi',
        name: 'laporan-potensi',
        builder: (context, state) => const LaporanPotensiScreen(),
      ),

      // Modul Invoice Jatuh Tempo
      GoRoute(
        path: '/invoice-jatuh-tempo',
        name: 'invoice-jatuh-tempo',
        builder: (context, state) => const InvoiceJatuhTempoScreen(),
      ),

      // Modul Achievement
      GoRoute(
        path: '/achievement',
        name: 'achievement',
        builder: (context, state) => const AchievementScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            name: 'achievement-detail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return AchievementDetailUserScreen(
                userRow: extra['userRow'] as AchievementUserRow,
                fromYear: extra['fromYear'] as int,
                fromMonth: extra['fromMonth'] as int,
                toYear: extra['toYear'] as int,
                toMonth: extra['toMonth'] as int,
              );
            },
          ),
        ],
      ),

      // Modul Kurir
      GoRoute(
        path: '/kurir',
        name: 'kurir',
        builder: (context, state) => const KurirMenuScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-pengiriman',
            builder: (context, state) => const TambahPengirimanScreen(),
          ),
          GoRoute(
            path: 'proses',
            name: 'proses-pengiriman',
            builder: (context, state) {
              final item = state.extra as KurirRencanaItem;
              return ProsesPengirimanScreen(item: item);
            },
          ),
        ],
      ),

      // Ganti Password
      GoRoute(
        path: '/ganti-password',
        name: 'ganti-password',
        builder: (context, state) => const GantiPasswordScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Halaman tidak ditemukan: ${state.uri}'),
      ),
    ),
  );
});
