import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/kurir_model.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/kurir_repository.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/app_reload_button.dart';

class KurirMenuScreen extends ConsumerStatefulWidget {
  const KurirMenuScreen({super.key});

  @override
  ConsumerState<KurirMenuScreen> createState() => _KurirMenuScreenState();
}

class _KurirMenuScreenState extends ConsumerState<KurirMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<KurirRencanaItem> _jadwalList = [];
  List<KurirRencanaItem> _rencanaList = [];
  List<KurirRencanaItem> _selesaiList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(kurirRepositoryProvider);
    final now = DateTime.now();

    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 1);

    final startStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    try {
      final results = await Future.wait([
        repo.getJadwalKirim(startDate: startStr, endDate: endStr),
        repo.getRencanaKirim(startDate: startStr, endDate: endStr),
        repo.getSelesaiKirim(startDate: startStr, endDate: endStr),
      ]);

      if (mounted) {
        setState(() {
          _jadwalList = results[0];
          _rencanaList = results[1];
          _selesaiList = results[2];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmLogout() {
    final user = ref.read(authProvider).user;
    final userName = (user?.nama ?? '').toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Logout',
          style:
              TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Halo $userName, apakah Anda yakin ingin keluar dari aplikasi?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text('Ya, Logout',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final isTablet = ResponsiveHelper.isTablet(context);
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final maxContainerWidth = ResponsiveHelper.contentWidth(context);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContainerWidth),
                child: Column(
                  children: [
                    // 1. TOP HEADER & PROFIL KURIR
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF00B4D8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (user?.nama ?? 'KURIR').toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${user?.cabang ?? 'Cabang'} • Divisi Logistik',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppReloadButton(
                              onTap: _fetchData,
                              isLoading: _isLoading,
                              tooltip: 'Muat Ulang',
                              size: 38,
                              iconSize: 18,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _confirmLogout,
                              icon: const Icon(Icons.logout_rounded,
                                  color: Color(0xFFEF4444)),
                              tooltip: 'Keluar',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. SEGMENTED TAB BAR
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(15, 23, 42, 0.06),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: const Color(0xFF4F46E5),
                          unselectedLabelColor: const Color(0xFF64748B),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          tabs: [
                            Tab(text: 'Jadwal (${_jadwalList.length})'),
                            Tab(text: 'Rencana (${_rencanaList.length})'),
                            Tab(text: 'Selesai (${_selesaiList.length})'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. TAB VIEW (Adaptif Grid di Tablet/Desktop)
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF4F46E5)),
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildAdaptiveList(
                                  items: _jadwalList,
                                  emptyMessage:
                                      'Belum ada jadwal pengiriman saat ini.',
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                  horizontalPadding: horizontalPadding,
                                ),
                                _buildAdaptiveList(
                                  items: _rencanaList,
                                  emptyMessage:
                                      'Belum ada rencana pengiriman terjadwal.',
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                  horizontalPadding: horizontalPadding,
                                ),
                                _buildAdaptiveList(
                                  items: _selesaiList,
                                  emptyMessage:
                                      'Belum ada pengiriman yang diselesaikan.',
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                  horizontalPadding: horizontalPadding,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 4,
        onPressed: () async {
          final refresh = await context.push<bool>('/kurir/tambah');
          if (refresh == true) _fetchData();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          '+ Kiriman Baru',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveList({
    required List<KurirRencanaItem> items,
    required String emptyMessage,
    required bool isDesktop,
    required bool isTablet,
    required double horizontalPadding,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 300,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    final crossAxisCount = (isDesktop || isTablet) ? 2 : 1;

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: _fetchData,
      child: crossAxisCount == 1
          ? ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 6, horizontalPadding, 80),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildKurirCard(items[index]),
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 6, horizontalPadding, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 180,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildKurirCard(items[index]),
            ),
    );
  }

  Widget _buildKurirCard(KurirRencanaItem item) {
    final isDelivered =
        item.status.toUpperCase() == 'SELESAI' || item.realisasi == 'Y';

    return AppCard(
      onTap: () async {
        if (!isDelivered) {
          final refresh = await context.push<bool>(
            '/kurir/proses',
            extra: item,
          );
          if (refresh == true) _fetchData();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.kodePengiriman,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4F46E5),
                      letterSpacing: -0.2,
                    ),
                  ),
                  AppBadge(
                    label: isDelivered ? 'Terkirim' : 'Menunggu',
                    variant: isDelivered
                        ? BadgeVariant.success
                        : BadgeVariant.warning,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.receiver.isNotEmpty)
                Text(
                  'Penerima: ${item.receiver}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (item.sender.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Pengirim: ${item.sender}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.note,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.tanggalPlan} ${item.jamPlan}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              if (!isDelivered)
                const Text(
                  'Proses Kirim →',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
