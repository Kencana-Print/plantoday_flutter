import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/app_reload_button.dart';

const _kShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

class VisitPlanScreen extends ConsumerStatefulWidget {
  const VisitPlanScreen({super.key});

  @override
  ConsumerState<VisitPlanScreen> createState() => _VisitPlanScreenState();
}

class _VisitPlanScreenState extends ConsumerState<VisitPlanScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  String _selectedCabang = 'JAKARTA';
  String _selectedSales = '';
  List<String> _salesList = [];

  bool _onlyBelum = false;
  List<VisitModel> _plans = [];
  bool _isLoading = false;
  VisitModel? _selectedPlan;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollFab = false;

  final List<String> _cabangOptions = ['JAKARTA', 'JATIM', 'JATENG', 'PUSAT'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show =
          _scrollController.hasClients && _scrollController.offset > 200;
      if (show != _showScrollFab) {
        setState(() => _showScrollFab = show);
      }
    });

    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    if (isManager) {
      _selectedCabang = 'JAKARTA';
      _selectedSales = '';
      _fetchSalesForCabang('JAKARTA');
    } else {
      if (user != null && user.cabang.isNotEmpty) {
        final cab = user.cabang.toUpperCase();
        if (_cabangOptions.contains(cab)) {
          _selectedCabang = cab;
        }
      }
      _selectedSales = user?.nama ?? '';
      _fetchPlans();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime d) {
    final mName = _kShortMonths[d.month - 1];
    return '${d.day} $mName ${d.year}';
  }

  String _formatYmd(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatItemDate(String? ymd) {
    if (ymd == null || ymd.trim().isEmpty) return '-';
    final trimmed = ymd.trim();
    try {
      if (trimmed.contains('-')) {
        final clean = trimmed.split('T')[0].split(' ')[0];
        final parts = clean.split('-').map(int.parse).toList();
        if (parts.length >= 3) {
          final day = parts[2];
          final month = parts[1];
          final year = parts[0];
          if (month >= 1 && month <= 12) {
            return '$day ${_kShortMonths[month - 1]} $year';
          }
        }
      }
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) {
        return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
      }
    } catch (_) {}
    return trimmed;
  }

  Future<void> _fetchSalesForCabang(String cabang) async {
    final repo = ref.read(visitRepositoryProvider);
    final sales = await repo.getSalesByCabang(cabang);

    if (mounted) {
      setState(() {
        _salesList = sales;
        _selectedSales = sales.isNotEmpty ? sales.first : '';
      });
      if (_selectedSales.isNotEmpty) {
        _fetchPlans();
      } else {
        setState(() {
          _plans = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPlans() async {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    final repo = ref.read(visitRepositoryProvider);

    final targetSales = isManager ? _selectedSales : (user?.nama ?? '');

    if (targetSales.isEmpty) {
      if (mounted) {
        setState(() {
          _plans = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedPlan = null;
    });

    final startStr = _formatYmd(_startDate);
    final endStr = _formatYmd(_endDate);

    final results = await repo.getVisitPlanList(
      cabang: _selectedCabang,
      sales: targetSales,
      startDate: startStr,
      endDate: endStr,
      isManager: isManager,
    );

    if (mounted) {
      setState(() {
        _plans = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showAppDateRangePicker(
      context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchPlans();
    }
  }

  Future<void> _handleKirimWA() async {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    final targetSales = isManager ? _selectedSales : (user?.nama ?? '');

    if (targetSales.isEmpty) {
      AppToast.error(context, 'Pilih sales terlebih dahulu');
      return;
    }

    final repo = ref.read(visitRepositoryProvider);
    final waText = await repo.getRekapVisitPlanWA(
      user: targetSales,
      cabang: _selectedCabang,
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
    );

    if (!mounted) return;

    if (waText == null || waText.trim().isEmpty) {
      AppToast.warning(context, 'Data rekap WhatsApp tidak tersedia');
      return;
    }

    _showWhatsAppOptionModal(waText);
  }

  void _showWhatsAppOptionModal(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kirim lewat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              const SizedBox(height: 8),

              // Tombol WhatsApp Biasa
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(text)}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Tombol WhatsApp Business
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF128C7E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.business_center_rounded, size: 18),
                  label: const Text(
                    'WhatsApp Business',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(text)}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Batal
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color.fromRGBO(15, 23, 42, 0.12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCabangPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Cabang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ..._cabangOptions.map((cab) {
                final isSelected = _selectedCabang == cab;
                return ListTile(
                  title: Text(
                    cab,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4F46E5),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_selectedCabang != cab) {
                      setState(() => _selectedCabang = cab);
                      final isManager =
                          ref.read(authProvider).user?.jabatan.toUpperCase() ==
                          'MANAGER';
                      if (isManager) {
                        _fetchSalesForCabang(cab);
                      } else {
                        _fetchPlans();
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalesPicker() {
    if (_salesList.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _salesList.length,
                  separatorBuilder: (ctx, i) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final salesName = _salesList[i];
                    final isSelected =
                        _selectedSales.toLowerCase() == salesName.toLowerCase();
                    return ListTile(
                      title: Text(
                        salesName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4F46E5),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (_selectedSales != salesName) {
                          setState(() => _selectedSales = salesName);
                          _fetchPlans();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    final filteredPlans = _plans.where((p) {
      if (_onlyBelum) {
        return p.realisasi != 'Y';
      }
      return true;
    }).toList();

    final displayedSalesName = isManager
        ? (_selectedSales.isNotEmpty ? _selectedSales : 'Pilih Sales')
        : (user?.nama ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: ResponsiveHelper.contentWidth(context),
          child: Column(
            children: [
              // 1. TOP HEADER PERSIS SCREENSHOT IMAGE 1
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    // Tombol Back Kiri
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.03),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),

                    // Judul & Subjudul Tengah
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            'Visit Plan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekap rencana kunjungan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Aksi Kanan: Kirim WA + Reload
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Kirim Rekap WA',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleKirimWA,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(34, 197, 94, 0.25),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.call_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppReloadButton(
                          onTap: _fetchPlans,
                          isLoading: _isLoading,
                          tooltip: 'Segarkan data',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. FILTER CARD CONTAINER PERSIS SCREENSHOT IMAGE 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                      width: 1,
                    ),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Baris 1: CABANG & SALES Side-by-Side
                      Row(
                        children: [
                          // Kolom CABANG
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CABANG',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: isManager ? _showCabangPicker : null,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                          15,
                                          23,
                                          42,
                                          0.06,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedCabang,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (isManager)
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Color(0xFF64748B),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Kolom SALES
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SALES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: isManager ? _showSalesPicker : null,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                          15,
                                          23,
                                          42,
                                          0.06,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayedSalesName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isManager)
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Color(0xFF64748B),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Baris 2: RENTANG TANGGAL
                      const Text(
                        'RENTANG TANGGAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _selectDateRange,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                _formatDisplayDate(_startDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              Text(
                                _formatDisplayDate(_endDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. SUB-FILTER ROW ([ ] Belum & Menampilkan: X data)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Checkbox Kapsul [ ] Belum
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _onlyBelum = !_onlyBelum),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _onlyBelum
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _onlyBelum
                                ? const Color(0xFF4F46E5)
                                : const Color.fromRGBO(15, 23, 42, 0.12),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _onlyBelum
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _onlyBelum
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF94A3B8),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _onlyBelum
                                  ? const Icon(
                                      Icons.check,
                                      size: 11,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Belum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _onlyBelum
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Teks Menampilkan: X data
                    Text(
                      _isLoading
                          ? 'Memuat data...'
                          : 'Menampilkan: ${filteredPlans.length} data',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 4. CONTENT LIST / EMPTY STATE
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : filteredPlans.isEmpty
                    ? const Center(
                        child: Text(
                          'Data visit plan tidak ditemukan.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF4F46E5),
                        onRefresh: _fetchPlans,
                        child: NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (_selectedPlan != null) {
                              setState(() => _selectedPlan = null);
                            }
                            return false;
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: filteredPlans.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final plan = filteredPlans[index];
                              final isDone = plan.realisasi == 'Y';
                              final isSelected = _selectedPlan?.id == plan.id;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    if (_selectedPlan?.id == plan.id) {
                                      _selectedPlan = null;
                                    } else {
                                      _selectedPlan = plan;
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF4F4FD)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : const Color.fromRGBO(
                                              15,
                                              23,
                                              42,
                                              0.08,
                                            ),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: AppShadows.softCard,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.cusNama,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 13,
                                                  color: Color(0xFF00B4D8),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatItemDate(plan.tanggal),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (plan.cusAlamat.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                plan.cusAlamat,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.1)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          isDone ? 'DONE' : 'BELUM',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isDone
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),

              // 5. BOTTOM FIXED ACTION BAR (Jika Bukan Manager)
              if (!isManager)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color.fromRGBO(15, 23, 42, 0.08)),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () async {
                        final refresh = await context.push<bool>(
                          '/visit-plan/tambah',
                        );
                        if (refresh == true) _fetchPlans();
                      },
                      child: const Text(
                        '+ Tambah',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Floating Action Buttons ala React Native saat item dipilih
      floatingActionButton: (_selectedPlan != null)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // FAB Visit muncul jika item belum terealisasi
                if (_selectedPlan!.realisasi != 'Y') ...[
                  FloatingActionButton.extended(
                    heroTag: 'fab_vp_visit',
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 4,
                    onPressed: () async {
                      final plan = _selectedPlan!;
                      setState(() => _selectedPlan = null);
                      final cust = CustomerModel(
                        kode: plan.cusKode ?? '',
                        nama: plan.cusNama,
                        alamat: plan.cusAlamat,
                      );
                      final refresh = await context.push<bool>(
                        '/visit/tambah',
                        extra: cust,
                      );
                      if (refresh == true) _fetchPlans();
                    },
                    icon: const Icon(
                      Icons.directions_run_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Visit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // FAB Edit
                FloatingActionButton.extended(
                  heroTag: 'fab_vp_edit',
                  backgroundColor: const Color(0xFF4F46E5),
                  elevation: 4,
                  onPressed: () async {
                    final plan = _selectedPlan!;
                    setState(() => _selectedPlan = null);
                    final isDone = plan.realisasi == 'Y';
                    final refresh = await context.push<bool>(
                      isDone ? '/visit/edit' : '/visit-plan/edit',
                      extra: plan,
                    );
                    if (refresh == true) _fetchPlans();
                  },
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
