import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/asset_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_jatuh_tempo_model.dart';
import '../../models/penawaran_model.dart';
import '../../models/permintaan_harga_model.dart';
import '../../models/potensi_model.dart';
import '../../models/tracking_model.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/version_provider.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/invoice_jatuh_tempo_repository.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../repositories/potensi_repository.dart';
import '../../repositories/tracking_repository.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/web_shortcut_guide_modal.dart';
import '../../widgets/app_reload_button.dart';

const _kIndonesianMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _skeletonController;
  late Animation<double> _skeletonPulse;

  DateTime _selectedVisitPlanDate = DateTime.now();
  bool _isLoading = true;

  // Selected Months for the 3 modules
  int _phMonth = DateTime.now().month;
  int _phYear = DateTime.now().year;

  int _penawaranMonth = DateTime.now().month;
  int _penawaranYear = DateTime.now().year;

  int _spkMonth = DateTime.now().month;
  int _spkYear = DateTime.now().year;

  // Status Counts
  Map<String, int> _phStatusCounts = {
    'BELUM': 0,
    'MINTA': 0,
    'WAIT': 0,
    'NEGO': 0,
    'DONE': 0,
    'CANCEL': 0,
  };
  Map<String, int> _penawaranStatusCounts = {
    'OPEN': 0,
    'PARSIAL': 0,
    'CLOSE': 0,
  };
  Map<String, int> _spkStatusCounts = {'BELUM': 0, 'PROSES': 0, 'SUDAH': 0};

  int _unapprovedPenawaranCount = 0;

  DateTime? _lastBackPressTime;
  String _selectedVisitPlanSales = 'ALL';
  bool _showAllVisits = false;

  // Data states
  List<VisitModel> _visitPlans = [];
  AchievementUserRow? _myAchievement;
  List<PotensiListItem> _rawPotensiItems = [];
  String _selectedPotensiSales = 'ALL';
  bool _isPotensiExpanded = false;

  // Invoice Jatuh Tempo Data states
  InvoiceJatuhTempoSummary? _invoiceJatuhTempoSummary;
  List<InvoiceJatuhTempoItem> _rawInvoiceJatuhTempoItems = [];
  String _selectedJatuhTempoSales = 'ALL';
  bool _isJatuhTempoExpanded = false;
  final Set<String> _expandedHomeInkasoSales = <String>{};

  List<PermintaanHargaItem> _recentPh = [];
  List<TrackingPenawaranListItem> _recentPenawaran = [];
  List<TrackingSpkListItem> _recentSpk = [];

  // Filtered Visit Plan
  List<String> get _availableVisitPlanSales {
    final set = <String>{};
    for (final vp in _visitPlans) {
      final s = vp.salesName ?? '';
      if (s.isNotEmpty) set.add(s.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<VisitModel> get _filteredVisitPlans {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    if (!isManager || _selectedVisitPlanSales == 'ALL') return _visitPlans;
    return _visitPlans.where((vp) {
      final s = vp.salesName ?? '';
      return s.toLowerCase() == _selectedVisitPlanSales.toLowerCase();
    }).toList();
  }

  void _showVisitPlanSalesPicker() {
    final list = _availableVisitPlanSales;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales (Visit Plan)',
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
              const Divider(height: 12),
              ListTile(
                title: const Text(
                  'Semua Sales',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: _selectedVisitPlanSales == 'ALL'
                    ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                    : null,
                onTap: () {
                  setState(() => _selectedVisitPlanSales = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              ...list.map((salesName) {
                final isSelected =
                    _selectedVisitPlanSales.toLowerCase() ==
                    salesName.toLowerCase();
                return ListTile(
                  title: Text(
                    salesName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                      : null,
                  onTap: () {
                    setState(() => _selectedVisitPlanSales = salesName);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Computed Totals for Quick Stats
  int get _totalActivePH =>
      (_phStatusCounts['BELUM'] ?? 0) +
      (_phStatusCounts['MINTA'] ?? 0) +
      (_phStatusCounts['WAIT'] ?? 0);

  int get _totalActivePenawaran =>
      (_penawaranStatusCounts['OPEN'] ?? 0) +
      (_penawaranStatusCounts['PARSIAL'] ?? 0);

  int get _totalActiveSpk =>
      (_spkStatusCounts['BELUM'] ?? 0) + (_spkStatusCounts['PROSES'] ?? 0);

  int get _grandTotalNotifications {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    return _totalActivePH +
        _totalActivePenawaran +
        _totalActiveSpk +
        (isManager ? _unapprovedPenawaranCount : 0);
  }

  // Filtered Potensi
  List<String> get _availablePotensiSales {
    final set = <String>{};
    for (final it in _rawPotensiItems) {
      if (it.salesNama.isNotEmpty) set.add(it.salesNama.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  void _showPotensiSalesPicker() {
    final list = _availablePotensiSales;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales (Potensi)',
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
              const Divider(height: 12),
              ListTile(
                title: const Text(
                  'Semua Sales',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: _selectedPotensiSales == 'ALL'
                    ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                    : null,
                onTap: () {
                  setState(() => _selectedPotensiSales = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              ...list.map((salesName) {
                final isSelected =
                    _selectedPotensiSales.toLowerCase() ==
                    salesName.toLowerCase();
                return ListTile(
                  title: Text(
                    salesName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                      : null,
                  onTap: () {
                    setState(() => _selectedPotensiSales = salesName);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<PotensiListItem> get _filteredPotensiItems {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    return _rawPotensiItems.where((it) {
      final s = it.status.toUpperCase();
      final isOpen = s == 'OPEN' || s == 'POTENSI' || s.isEmpty;
      if (!isOpen) return false;

      if (isManager && _selectedPotensiSales != 'ALL') {
        final sal = it.salesNama;
        return sal.toLowerCase() == _selectedPotensiSales.toLowerCase();
      }
      return true;
    }).toList();
  }

  double get _totalNominalPotensi =>
      _filteredPotensiItems.fold(0.0, (acc, it) => acc + it.harga);

  // Filtered Jatuh Tempo
  List<String> get _availableJatuhTempoSales {
    final set = <String>{};
    if (_invoiceJatuhTempoSummary?.bySales != null) {
      for (final s in _invoiceJatuhTempoSummary!.bySales) {
        if (s.salNama.isNotEmpty && s.salNama != '(Tanpa Sales)') {
          set.add(s.salNama.trim());
        }
      }
    }
    for (final it in _rawInvoiceJatuhTempoItems) {
      if (it.salNama.isNotEmpty && it.salNama != '(Tanpa Sales)') {
        set.add(it.salNama.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  void _showJatuhTempoSalesPicker() {
    final list = _availableJatuhTempoSales;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sales (Jatuh Tempo)',
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
              const Divider(height: 12),
              ListTile(
                title: const Text(
                  'Semua Sales',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: _selectedJatuhTempoSales == 'ALL'
                    ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                    : null,
                onTap: () {
                  setState(() => _selectedJatuhTempoSales = 'ALL');
                  Navigator.pop(ctx);
                },
              ),
              ...list.map((salesName) {
                final isSelected =
                    _selectedJatuhTempoSales.toLowerCase() ==
                    salesName.toLowerCase();
                return ListTile(
                  title: Text(
                    salesName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                      : null,
                  onTap: () {
                    setState(() => _selectedJatuhTempoSales = salesName);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<InvoiceJatuhTempoItem> get _filteredJatuhTempoItems {
    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    return _rawInvoiceJatuhTempoItems.where((it) {
      if (isManager && _selectedJatuhTempoSales != 'ALL') {
        final sal = it.salNama.toLowerCase().trim();
        final selected = _selectedJatuhTempoSales.toLowerCase().trim();
        return sal == selected || sal.contains(selected) || selected.contains(sal);
      }
      return true;
    }).toList();
  }

  double get _totalNominalJatuhTempo =>
      _filteredJatuhTempoItems.fold(0.0, (acc, it) => acc + it.sisa);

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _skeletonPulse = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      if (user?.jabatan.toUpperCase() == 'KURIR') {
        context.go('/kurir');
        return;
      }
    });
    _fetchDashboardData();
  }

  Future<void> _selectVisitPlanDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedVisitPlanDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedVisitPlanDate) {
      setState(() => _selectedVisitPlanDate = picked);
      _fetchDashboardData();
    }
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _getRangeStart(int month, int year) =>
      '$year-${month.toString().padLeft(2, '0')}-01';

  String _getRangeEnd(int month, int year) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    final selectedDateStr = _formatYmd(_selectedVisitPlanDate);
    final phStart = _getRangeStart(_phMonth, _phYear);
    final phEnd = _getRangeEnd(_phMonth, _phYear);
    final penStart = _getRangeStart(_penawaranMonth, _penawaranYear);
    final penEnd = _getRangeEnd(_penawaranMonth, _penawaranYear);
    final spkStart = _getRangeStart(_spkMonth, _spkYear);
    final spkEnd = _getRangeEnd(_spkMonth, _spkYear);

    final now = DateTime.now();
    final curStart = _getRangeStart(now.month, now.year);
    final curEnd = _getRangeEnd(now.month, now.year);

    final visitRepo = ref.read(visitRepositoryProvider);
    final achRepo = ref.read(achievementRepositoryProvider);
    final phRepo = ref.read(permintaanHargaRepositoryProvider);
    final trackingRepo = ref.read(trackingRepositoryProvider);
    final potensiRepo = ref.read(potensiRepositoryProvider);
    final penawaranRepo = ref.read(penawaranRepositoryProvider);
    final jatuhTempoRepo = ref.read(invoiceJatuhTempoRepositoryProvider);

    try {
      final results = await Future.wait([
        // 0: visit plan
        visitRepo.getVisitPlanList(
          cabang: user?.cabang ?? '',
          sales: user?.nama ?? '',
          startDate: selectedDateStr,
          endDate: selectedDateStr,
          isManager: isManager,
        ),
        // 1: ph counts
        phRepo.getStatusCounts(startDate: phStart, endDate: phEnd),
        // 2: ph recent list
        phRepo.getList(startDate: phStart, endDate: phEnd),
        // 3: penawaran counts
        trackingRepo.getTrackingPenawaranStatusCounts(
          startDate: penStart,
          endDate: penEnd,
        ),
        // 4: penawaran recent list
        trackingRepo.getTrackingPenawaranList(
          startDate: penStart,
          endDate: penEnd,
        ),
        // 5: spk counts
        trackingRepo.getTrackingSpkStatusCounts(
          startDate: spkStart,
          endDate: spkEnd,
        ),
        // 6: spk recent list
        trackingRepo.getTrackingSpkList(startDate: spkStart, endDate: spkEnd),
        // 7: achievement range
        achRepo.getOmsetRange(
          fromYear: now.year,
          fromMonth: now.month,
          toYear: now.year,
          toMonth: now.month,
        ),
        // 8: potensi list
        potensiRepo.getPotensiList(startDate: curStart, endDate: curEnd),
        // 9: unapproved penawaran for manager
        isManager
            ? penawaranRepo.getPenawaranList(
                approvalStatus: 'UNAPPROVED',
                limit: 100,
              )
            : Future.value(<PenawaranListItem>[]),
        // 10: invoice jatuh tempo (seluruh tagihan overdue tanpa batas tanggal)
        jatuhTempoRepo.getInvoiceJatuhTempo(),
      ]);

      if (mounted) {
        final visitList = results[0] as List<VisitModel>;
        final phCounts = results[1] as Map<String, int>;
        final phList = results[2] as List<PermintaanHargaItem>;
        final penCounts = results[3] as Map<String, int>;
        final penList = results[4] as List<TrackingPenawaranListItem>;
        final spkCounts = results[5] as Map<String, int>;
        final spkList = results[6] as List<TrackingSpkListItem>;
        final achRows = results[7] as List<AchievementUserRow>;
        final potensiRes = results[8] as PotensiResult;
        final unapprovedList = results[9] as List<PenawaranListItem>;
        final jatuhTempoRes = results[10] as InvoiceJatuhTempoResult;

        AchievementUserRow? myAch;
        if (achRows.isNotEmpty) {
          if (isManager) {
            final totalTarget = achRows.fold<double>(
              0,
              (acc, r) => acc + r.target,
            );
            final totalReal = achRows.fold<double>(
              0,
              (acc, r) => acc + r.realisasi,
            );
            final achPct = totalTarget > 0
                ? (totalReal / totalTarget) * 100
                : 0.0;
            myAch = AchievementUserRow(
              kode: 'ALL',
              nama: 'Rekap Semua User',
              target: totalTarget,
              realisasi: totalReal,
              ach: achPct.clamp(0, 500),
            );
          } else {
            myAch = achRows.firstWhere(
              (r) => r.nama.toLowerCase() == (user?.nama ?? '').toLowerCase(),
              orElse: () => achRows.first,
            );
          }
        }

        setState(() {
          _visitPlans = visitList;
          _phStatusCounts = phCounts;
          _recentPh = phList.take(3).toList();
          _penawaranStatusCounts = penCounts;
          _recentPenawaran = penList.take(3).toList();
          _spkStatusCounts = spkCounts;
          _recentSpk = spkList.take(3).toList();
          _myAchievement = myAch;
          _rawPotensiItems = potensiRes.list;
          _unapprovedPenawaranCount = unapprovedList.length;
          _invoiceJatuhTempoSummary = jatuhTempoRes.summary;
          _rawInvoiceJatuhTempoItems = jatuhTempoRes.items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  void _showMonthYearPicker({
    required String target,
    required int currentMonth,
    required int currentYear,
    required void Function(int m, int y) onApply,
  }) {
    int tempMonth = currentMonth;
    int tempYear = currentYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Periode ($target)',
                      style: const TextStyle(
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: tempMonth,
                        decoration: const InputDecoration(labelText: 'Bulan'),
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text(_kIndonesianMonths[i]),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: tempYear,
                        decoration: const InputDecoration(labelText: 'Tahun'),
                        items: [2024, 2025, 2026, 2027].map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempYear = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onApply(tempMonth, tempYear);
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusDetailModal() {
    final user = ref.read(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.82,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.12),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicator Bar
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Modal Title
                  const Text(
                    'Rincian Status Dokumen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Permintaan Harga
                          _buildModalSectionHeader(
                            title: 'Permintaan Harga',
                            totalBadge: _totalActivePH,
                          ),
                          const SizedBox(height: 6),
                          _buildStatusItemRow(
                            icon: Icons.schedule,
                            color: const Color(0xFF6B7280),
                            label: 'Belum',
                            count: _phStatusCounts['BELUM'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),
                          _buildStatusItemRow(
                            icon: Icons.description,
                            color: const Color(0xFFDC2626),
                            label: 'Minta',
                            count: _phStatusCounts['MINTA'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),
                          _buildStatusItemRow(
                            icon: Icons.hourglass_empty,
                            color: const Color(0xFF16A34A),
                            label: 'Wait',
                            count: _phStatusCounts['WAIT'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),
                          _buildStatusItemRow(
                            icon: Icons.handshake,
                            color: const Color(0xFF6B21A8),
                            label: 'Nego',
                            count: _phStatusCounts['NEGO'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),
                          _buildStatusItemRow(
                            icon: Icons.check_circle,
                            color: const Color(0xFF18181B),
                            label: 'Done',
                            count: _phStatusCounts['DONE'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),
                          _buildStatusItemRow(
                            icon: Icons.cancel,
                            color: const Color(0xFF2563EB),
                            label: 'Cancel',
                            count: _phStatusCounts['CANCEL'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/permintaan-harga');
                            },
                          ),

                          // 2. Tracking Penawaran
                          const SizedBox(height: 16),
                          _buildModalSectionHeader(
                            title: 'Tracking Penawaran',
                            totalBadge: _totalActivePenawaran,
                          ),
                          const SizedBox(height: 6),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFFEF4444),
                            label: 'OPEN',
                            count: _penawaranStatusCounts['OPEN'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/penawaran');
                            },
                          ),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFF3B82F6),
                            label: 'PARSIAL',
                            count: _penawaranStatusCounts['PARSIAL'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/penawaran');
                            },
                          ),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFF10B981),
                            label: 'CLOSE',
                            count: _penawaranStatusCounts['CLOSE'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/penawaran');
                            },
                          ),

                          // 3. Penawaran (Approval) - Khusus Manager
                          if (isManager) ...[
                            const SizedBox(height: 16),
                            _buildModalSectionHeader(
                              title: 'Penawaran (Approval)',
                              totalBadge: _unapprovedPenawaranCount,
                            ),
                            const SizedBox(height: 6),
                            _buildStatusItemRow(
                              icon: Icons.schedule,
                              color: const Color(0xFFF59E0B),
                              badgeColor: _unapprovedPenawaranCount > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              label: 'Belum Diapprove',
                              count: _unapprovedPenawaranCount,
                              onTap: () {
                                Navigator.pop(dialogCtx);
                                context.push('/penawaran');
                              },
                            ),
                          ],

                          // 4. Tracking SPK
                          const SizedBox(height: 16),
                          _buildModalSectionHeader(
                            title: 'Tracking SPK',
                            totalBadge: _totalActiveSpk,
                          ),
                          const SizedBox(height: 6),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFFEF4444),
                            label: 'OPEN',
                            count: _spkStatusCounts['BELUM'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/tracking-spk');
                            },
                          ),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFFF59E0B),
                            label: 'PROSES',
                            count: _spkStatusCounts['PROSES'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/tracking-spk');
                            },
                          ),
                          _buildStatusItemRow(
                            dotColor: const Color(0xFF10B981),
                            label: 'CLOSE',
                            count: _spkStatusCounts['SUDAH'] ?? 0,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              context.push('/tracking-spk');
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action Row: Tutup Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalSectionHeader({
    required String title,
    required int totalBadge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4F46E5),
          ),
        ),
        if (totalBadge > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            alignment: Alignment.center,
            child: Text(
              '$totalBadge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusItemRow({
    IconData? icon,
    Color? color,
    Color? dotColor,
    Color? badgeColor,
    required String label,
    required int count,
    VoidCallback? onTap,
  }) {
    final effectiveBadgeColor =
        badgeColor ?? dotColor ?? color ?? const Color(0xFF4F46E5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (icon != null)
                      Icon(icon, size: 16, color: color)
                    else if (dotColor != null)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    final dashboardBody = RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 28,
          vertical: isMobile ? 14 : 20,
        ),
        child: ResponsiveContainer(
          maxWidth: isMobile ? 540 : ResponsiveHelper.contentWidth(context),
          child: isMobile
              ? _buildMobileDashboardLayout(user, isManager, currencyFormat)
              : _buildDesktopDashboardLayout(user, isManager, currencyFormat),
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppToast.info(
            context,
            'Tekan sekali lagi untuk keluar aplikasi',
            duration: const Duration(seconds: 2),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF7F9FF),
        drawer: isMobile ? _buildSidebarDrawer(user) : null,
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop)
                _buildDesktopSidebar(user)
              else if (isTablet)
                _buildTabletNavigationRail(user),
              Expanded(child: dashboardBody),
            ],
          ),
        ),
      ),
    );
  }

  // ── LAYOUT MOBILE DASHBOARD (1 Kolom Vertikal)
  Widget _buildMobileDashboardLayout(
    dynamic user,
    bool isManager,
    NumberFormat currencyFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(isMobile: true),
        if (_isLoading) ...[
          const SizedBox(height: 8),
          _buildLinearLoadingIndicator(),
        ],
        const SizedBox(height: 18),
        _buildGreetingCard(user),
        const SizedBox(height: 14),
        _buildQuickStatsRow(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _isLoading
              ? KeyedSubtree(
                  key: const ValueKey('mobile_skeleton'),
                  child: _buildSkeletonDashboard(),
                )
              : KeyedSubtree(
                  key: const ValueKey('mobile_content'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildVisitPlanCard(isManager),
                      const SizedBox(height: 14),
                      _buildAchievementCard(currencyFormat),
                      const SizedBox(height: 14),
                      _buildPotensiCard(currencyFormat),
                      const SizedBox(height: 14),
                      _buildInvoiceJatuhTempoCard(currencyFormat),
                      const SizedBox(height: 14),
                      _buildPhModuleCard(),
                      const SizedBox(height: 14),
                      _buildPenawaranModuleCard(),
                      const SizedBox(height: 14),
                      _buildSpkModuleCard(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── LAYOUT DESKTOP & TABLET DASHBOARD (Full-Width Melebar Responsif)
  Widget _buildDesktopDashboardLayout(
    dynamic user,
    bool isManager,
    NumberFormat currencyFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(isMobile: false),
        if (_isLoading) ...[
          const SizedBox(height: 8),
          _buildLinearLoadingIndicator(),
        ],
        const SizedBox(height: 18),
        // Baris Header: Greeting & Quick Stats berdampingan (Rasio Selaras 1:1 & Tinggi Sejajar)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 1, child: _buildGreetingCard(user)),
              const SizedBox(width: 14),
              Expanded(flex: 1, child: _buildQuickStatsRow(fillHeight: true)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _isLoading
              ? KeyedSubtree(
                  key: const ValueKey('desktop_skeleton'),
                  child: _buildSkeletonDashboard(),
                )
              : KeyedSubtree(
                  key: const ValueKey('desktop_content'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildVisitPlanCard(isManager),
                      const SizedBox(height: 16),
                      _buildAchievementCard(currencyFormat),
                      const SizedBox(height: 16),
                      _buildPotensiCard(currencyFormat),
                      const SizedBox(height: 16),
                      _buildInvoiceJatuhTempoCard(currencyFormat),
                      const SizedBox(height: 16),
                      _buildPhModuleCard(),
                      const SizedBox(height: 16),
                      _buildPenawaranModuleCard(),
                      const SizedBox(height: 16),
                      _buildSpkModuleCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── TOP BAR NAVIGASI (Adaptif Mobile / Desktop)
  Widget _buildTopBar({required bool isMobile}) {
    if (isMobile) {
      return SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tombol Hamburger Menu (Sisi Kiri)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.menu_rounded,
                    size: 22,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),

            // Logo PlanToday Gradient Text + Versi (Benar-benar di Tengah Presisi Layar)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: const Text(
                    'PlanToday',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'v${ref.watch(versionProvider).currentVersion}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),

            // Tombol Aksi Kanan: Reload + Notifikasi (Sisi Kanan)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppReloadButton(
                    onTap: _fetchDashboardData,
                    isLoading: _isLoading,
                    tooltip: 'Segarkan data dashboard',
                  ),
                  const SizedBox(width: 8),
                  _buildNotificationButton(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Tombol Segarkan Data
              AppReloadButton(
                onTap: _fetchDashboardData,
                isLoading: _isLoading,
                tooltip: 'Segarkan data dashboard',
              ),
              const SizedBox(width: 10),
              _buildNotificationButton(),
            ],
          ),
        ],
      );
    }
  }

  // ── TOMBOL NOTIFIKASI LONCENG
  Widget _buildNotificationButton() {
    return Tooltip(
      message: 'Rincian Status Dokumen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showStatusDetailModal,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0x144F46E5), // rgba(79,70,229,0.08)
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0x2E4F46E5), // rgba(79,70,229,0.18)
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_rounded,
                size: 20,
                color: Color(0xFF4F46E5),
              ),
            ),
            if (_grandTotalNotifications > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_grandTotalNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── LOADING INDICATOR BAR
  Widget _buildLinearLoadingIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: const LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
      ),
    );
  }

  // ── KARTU PROFIL / SAMBUTAN
  Widget _buildGreetingCard(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _buildCardTopAccent(
              accentColor: const Color(0xFF4F46E5),
              horizontalInset: 24,
              ambientHeight: 52,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        _formatDateShort(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (user?.nama ?? 'User').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}'
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK STATS ROW
  Widget _buildQuickStatsRow({bool fillHeight = false}) {
    return Row(
      crossAxisAlignment: fillHeight
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildQuickStatCard(
            number: '$_totalActivePH',
            label: 'PH Pending',
            color: const Color(0xFFEF4444),
            onTap: () => context.push('/permintaan-harga'),
            fillHeight: fillHeight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            number: '$_totalActivePenawaran',
            label: 'Penawaran Open',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push('/penawaran'),
            fillHeight: fillHeight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            number: '$_totalActiveSpk',
            label: 'SPK Open',
            color: const Color(0xFF10B981),
            onTap: () => context.push('/tracking-spk'),
            fillHeight: fillHeight,
          ),
        ),
      ],
    );
  }

  // ── KARTU VISIT PLAN
  Widget _buildVisitPlanCard(bool isManager) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _buildCardTopAccent(accentColor: const Color(0xFF4F46E5)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _filteredVisitPlans.isNotEmpty
                                ? (() {
                                    final doneCount = _filteredVisitPlans.where(
                                      (vp) {
                                        return (vp.realisasi?.toUpperCase() ==
                                            'Y');
                                      },
                                    ).length;
                                    return 'Visit Plan ($doneCount/${_filteredVisitPlans.length})';
                                  })()
                                : 'Visit Plan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      if (isManager) ...[
                        if (_availableVisitPlanSales.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showVisitPlanSalesPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedVisitPlanSales == 'ALL'
                                        ? 'Semua Sales'
                                        : _selectedVisitPlanSales,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/visit-plan/tambah'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 16,
                                  color: Color(0xFF4F46E5),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Buat Plan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Navigator Tanggal Stepper (< [icon] Tanggal >)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedVisitPlanDate = _selectedVisitPlanDate
                                  .subtract(const Duration(days: 1));
                            });
                            _fetchDashboardData();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.08),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _selectVisitPlanDate,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDateShort(_selectedVisitPlanDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedVisitPlanDate = _selectedVisitPlanDate
                                  .add(const Duration(days: 1));
                            });
                            _fetchDashboardData();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.08),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Empty State / List Visit Plan
                  if (_visitPlans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          const Text(
                            'Tidak ada jadwal visit plan untuk tanggal ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (!isManager) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(
                                  color: Color(0xFF4F46E5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () =>
                                  context.push('/visit-plan/tambah'),
                              child: const Text(
                                'Buat Visit Plan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (_filteredVisitPlans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Tidak ada jadwal visit plan untuk sales ini pada tanggal terpilih.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final displayedVisits = (isManager && !_showAllVisits)
                            ? _filteredVisitPlans.take(2).toList()
                            : _filteredVisitPlans;

                        return Column(
                          children: [
                            ...displayedVisits.map((vp) {
                              final isSudah =
                                  (vp.realisasi?.toUpperCase() == 'Y');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color.fromRGBO(
                                      15,
                                      23,
                                      42,
                                      0.06,
                                    ),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (isSudah) {
                                        context.push('/visit/edit', extra: vp);
                                      } else {
                                        context.push(
                                          '/visit-plan/edit',
                                          extra: vp,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
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
                                                  vp.cusNama,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (vp.salesName != null &&
                                                    vp
                                                        .salesName!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.person,
                                                        size: 12,
                                                        color: Color(
                                                          0xFF4F46E5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Sales: ${vp.salesName}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Color(
                                                            0xFF4F46E5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: 2),
                                                Text(
                                                  vp.cusAlamat.isNotEmpty
                                                      ? vp.cusAlamat
                                                      : '-',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                if (vp.note.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    vp.note,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          if (isSudah)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'SELESAI',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            )
                                          else if (isManager)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF6B7280,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'BELUM',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            )
                                          else
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF10B981,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                context.push(
                                                  '/visit/tambah',
                                                  extra: CustomerModel(
                                                    kode: vp.cusKode ?? '',
                                                    nama: vp.cusNama,
                                                    alamat: vp.cusAlamat,
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Visit',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (isManager &&
                                _filteredVisitPlans.length > 2) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(
                                    () => _showAllVisits = !_showAllVisits,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4F46E5,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _showAllVisits
                                            ? 'Sembunyikan Rencana Kunjungan'
                                            : 'Tampilkan ${_filteredVisitPlans.length - 2} Rencana Lainnya',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showAllVisits
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KARTU ACHIEVEMENT BULAN INI
  Widget _buildAchievementCard(NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _buildCardTopAccent(accentColor: const Color(0xFF6366F1)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 20,
                            color: Color(0xFF6366F1),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Achievement Bulan Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/achievement'),
                        child: const Row(
                          children: [
                            Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dua Kartu Target vs Realisasi
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target Bulan Ini',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(
                                  _myAchievement?.target ?? 0,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Realisasi Bulan Ini',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(
                                  _myAchievement?.realisasi ?? 0,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Persentase & Progress Bar
                  Builder(
                    builder: (context) {
                      final achReal = _myAchievement?.ach ?? 0.0;
                      final achColor = achReal >= 80
                          ? const Color(0xFF10B981)
                          : achReal >= 50
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444);

                      return Row(
                        children: [
                          Text(
                            '${achReal.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: achColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (achReal / 100).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  achColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KARTU POTENSI BULAN INI
  Widget _buildPotensiCard(NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _buildCardTopAccent(accentColor: const Color(0xFF0EA5E9)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 20,
                            color: Color(0xFF4F46E5),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Potensi Bulan Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/laporan-potensi'),
                        child: const Row(
                          children: [
                            Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Sales (untuk role Manager)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showPotensiSalesPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromRGBO(15, 23, 42, 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Sales',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _selectedPotensiSales == 'ALL'
                                    ? 'Semua Sales'
                                    : _selectedPotensiSales,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Color(0xFF4F46E5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nominal Total & Button Toggle Dropdown Item
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Nominal Potensi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormat.format(_totalNominalPotensi),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4F46E5),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isPotensiExpanded = !_isPotensiExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isPotensiExpanded
                                ? const Color(0xFFEEF2FF)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isPotensiExpanded
                                  ? const Color(0xFF4F46E5)
                                  : const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_filteredPotensiItems.length} Item',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _isPotensiExpanded
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Icon(
                                _isPotensiExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _isPotensiExpanded
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // List Item Accordion jika dibuka
                  if (_isPotensiExpanded) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ..._filteredPotensiItems.take(5).map((pItem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pItem.namaItem,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    pItem.customerNama,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormat.format(pItem.harga),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KARTU INVOICE JATUH TEMPO (OVERDUE / PROYEKSI INKASO)
  Widget _buildInvoiceJatuhTempoCard(NumberFormat currencyFormat) {
    final filtered = _filteredJatuhTempoItems;
    final salesGroups = InkasoSalesGroup.groupItems(
      filtered,
      summaryBySales: _invoiceJatuhTempoSummary?.bySales,
    );
    final totalCount = filtered.length;
    final totalSisa = _totalNominalJatuhTempo;
    final groupsRealisasi = salesGroups.fold<double>(
      0.0,
      (acc, g) => acc + g.totalTerealisasi,
    );
    final totalTerealisasi =
        _selectedJatuhTempoSales == 'ALL' &&
            (_invoiceJatuhTempoSummary?.totalRealisasi ?? 0) > groupsRealisasi
        ? _invoiceJatuhTempoSummary!.totalRealisasi
        : groupsRealisasi;
    final totalBatal = _invoiceJatuhTempoSummary?.totalBatal ?? 0.0;

    String shortNum(double val) {
      if (val >= 1e12) return '${(val / 1e12).toStringAsFixed(1)}T';
      if (val >= 1e9) return '${(val / 1e9).toStringAsFixed(1)}M';
      if (val >= 1e6) return '${(val / 1e6).toStringAsFixed(1)}Jt';
      if (val >= 1e3) return '${(val / 1e3).toStringAsFixed(1)}Rb';
      return val.toStringAsFixed(0);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _buildCardTopAccent(accentColor: const Color(0xFFEA580C)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: Color(0xFFEA580C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Invoice Jatuh Tempo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/invoice-jatuh-tempo'),
                        child: const Row(
                          children: [
                            Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Sales (untuk role Manager)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showJatuhTempoSalesPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromRGBO(15, 23, 42, 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Sales',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _selectedJatuhTempoSales == 'ALL'
                                    ? 'Semua Sales'
                                    : _selectedJatuhTempoSales,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Color(0xFFEA580C),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4 Metrik Manksi: Invoice Aktif, Sisa Tagihan, Terealisasi, Batal
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildInkasoMiniStat(
                          'Invoice Aktif',
                          '$totalCount',
                          const Color(0xFF4F46E5),
                        ),
                        _buildInkasoMiniStat(
                          'Sisa Tagihan',
                          shortNum(totalSisa),
                          const Color(0xFFEA580C),
                        ),
                        _buildInkasoMiniStat(
                          'Terealisasi',
                          shortNum(totalTerealisasi),
                          const Color(0xFF10B981),
                        ),
                        _buildInkasoMiniStat(
                          'Batal',
                          shortNum(totalBatal),
                          const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Toggle Daftar Per Sales
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isJatuhTempoExpanded = !_isJatuhTempoExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isJatuhTempoExpanded
                            ? const Color(0xFFFFEDD5)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isJatuhTempoExpanded
                              ? const Color(0xFFEA580C)
                              : const Color.fromRGBO(15, 23, 42, 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rincian Per Sales (${salesGroups.length} Sales)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _isJatuhTempoExpanded
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Icon(
                            _isJatuhTempoExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _isJatuhTempoExpanded
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // List Per Sales & Detail Inkaso jika dibuka
                  if (_isJatuhTempoExpanded) ...[
                    const SizedBox(height: 10),
                    if (salesGroups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Tidak ada invoice jatuh tempo untuk filter ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...salesGroups.map((grp) {
                        final isSalExpanded = _expandedHomeInkasoSales
                            .contains(grp.salNama);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSalExpanded
                                  ? const Color(
                                      0xFFEA580C,
                                    ).withValues(alpha: 0.35)
                                  : const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (isSalExpanded) {
                                      _expandedHomeInkasoSales.remove(
                                        grp.salNama,
                                      );
                                    } else {
                                      _expandedHomeInkasoSales.add(grp.salNama);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 3,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              grp.salNama.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEA580C),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${grp.jmlInvoice} invoice',
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Sisa ${shortNum(grp.totalSisa)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFEA580C),
                                              ),
                                            ),
                                            if (grp.totalTerealisasi > 0)
                                              Text(
                                                'Terealisasi ${shortNum(grp.totalTerealisasi)}',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSalExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isSalExpanded) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: grp.items.take(10).map((invItem) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
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
                                                    '${invItem.notaTampil.isNotEmpty ? invItem.notaTampil : invItem.nota} · ${invItem.tempo} (${invItem.terlambatHari}h)',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    invItem.cusNama.isNotEmpty
                                                        ? invItem.cusNama
                                                        : invItem.cusKode,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  currencyFormat.format(
                                                    invItem.sisa,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFFEA580C),
                                                  ),
                                                ),
                                                if (invItem.terbayar > 0)
                                                  Text(
                                                    'Real: ${shortNum(invItem.terbayar)}',
                                                    style: const TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInkasoMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPhModuleCard() {
    return _buildStripeModuleCard(
      stripeColor: const Color(0xFFEF4444),
      title: 'Permintaan Harga Terbaru',
      periodText: '${_kShortMonths[_phMonth - 1]} $_phYear',
      onSelectPeriod: () {
        _showMonthYearPicker(
          target: 'PH',
          currentMonth: _phMonth,
          currentYear: _phYear,
          onApply: (m, y) {
            setState(() {
              _phMonth = m;
              _phYear = y;
            });
            _fetchDashboardData();
          },
        );
      },
      onViewAll: () => context.push('/permintaan-harga'),
      chips: [
        _buildChip(
          'MINTA: ${_phStatusCounts['MINTA'] ?? 0}',
          bg: const Color(0xFFFEE2E2),
          border: const Color(0xFFFCA5A5),
          text: const Color(0xFFDC2626),
        ),
        _buildChip(
          'WAIT: ${_phStatusCounts['WAIT'] ?? 0}',
          bg: const Color(0xFFDCFCE7),
          border: const Color(0xFF86EFAC),
          text: const Color(0xFF16A34A),
        ),
        _buildChip(
          'DONE: ${_phStatusCounts['DONE'] ?? 0}',
          bg: const Color(0xFFF1F5F9),
          border: const Color(0xFFCBD5E1),
          text: const Color(0xFF475569),
        ),
      ],
      segmentedBar: _buildSegmentedBar([
        _Segment(
          count: _phStatusCounts['MINTA'] ?? 0,
          color: const Color(0xFFEF4444),
        ),
        _Segment(
          count: _phStatusCounts['WAIT'] ?? 0,
          color: const Color(0xFF10B981),
        ),
        _Segment(
          count: _phStatusCounts['DONE'] ?? 0,
          color: const Color(0xFF1E293B),
        ),
      ]),
      items: _recentPh.map((ph) {
        final phToken = PermintaanHargaStatusHelper.getToken(ph.status);
        return _buildRecentItemBox(
          code: ph.nomor,
          date: _formatItemDate(ph.tanggal),
          customer: ph.customer,
          detail: '${ph.nama} (${ph.divisi})',
          status: ph.status,
          statusColor: phToken.base,
          statusBg: phToken.unselectedBg,
        );
      }).toList(),
    );
  }

  // ── MODUL PENAWARAN TERBARU
  Widget _buildPenawaranModuleCard() {
    return _buildStripeModuleCard(
      stripeColor: const Color(0xFF3B82F6),
      title: 'Penawaran Terbaru',
      periodText: '${_kShortMonths[_penawaranMonth - 1]} $_penawaranYear',
      onSelectPeriod: () {
        _showMonthYearPicker(
          target: 'Penawaran',
          currentMonth: _penawaranMonth,
          currentYear: _penawaranYear,
          onApply: (m, y) {
            setState(() {
              _penawaranMonth = m;
              _penawaranYear = y;
            });
            _fetchDashboardData();
          },
        );
      },
      onViewAll: () => context.push('/penawaran'),
      chips: [
        _buildChip(
          'OPEN: ${_penawaranStatusCounts['OPEN'] ?? 0}',
          bg: const Color(0xFFFEE2E2),
          border: const Color(0xFFFCA5A5),
          text: const Color(0xFFDC2626),
        ),
        _buildChip(
          'PARSIAL: ${_penawaranStatusCounts['PARSIAL'] ?? 0}',
          bg: const Color(0xFFDBEAFE),
          border: const Color(0xFF93C5FD),
          text: const Color(0xFF2563EB),
        ),
        _buildChip(
          'CLOSE: ${_penawaranStatusCounts['CLOSE'] ?? 0}',
          bg: const Color(0xFFDCFCE7),
          border: const Color(0xFF86EFAC),
          text: const Color(0xFF16A34A),
        ),
      ],
      segmentedBar: _buildSegmentedBar([
        _Segment(
          count: _penawaranStatusCounts['OPEN'] ?? 0,
          color: const Color(0xFFEF4444),
        ),
        _Segment(
          count: _penawaranStatusCounts['PARSIAL'] ?? 0,
          color: const Color(0xFF3B82F6),
        ),
        _Segment(
          count: _penawaranStatusCounts['CLOSE'] ?? 0,
          color: const Color(0xFF10B981),
        ),
      ]),
      items: _recentPenawaran.map((pen) {
        final hasItems = pen.totalItem > 0;
        final progress = hasItems
            ? (pen.totalItemMap / pen.totalItem).clamp(0.0, 1.0)
            : 0.0;
        return _buildRecentItemBox(
          code: pen.noPenawaran,
          date: _formatItemDate(pen.tanggalPenawaran),
          customer: pen.customer,
          detail: '${pen.totalItemMap} dari ${pen.totalItem} item MAP',
          status: pen.statusTracking,
          statusColor: const Color(0xFFDC2626),
          statusBg: const Color(0xFFFEE2E2),
          progress: progress,
          progressColor: const Color(0xFFEF4444),
        );
      }).toList(),
    );
  }

  // ── MODUL SPK TERBARU
  Widget _buildSpkModuleCard() {
    return _buildStripeModuleCard(
      stripeColor: const Color(0xFF10B981),
      title: 'SPK Terbaru',
      periodText: '${_kShortMonths[_spkMonth - 1]} $_spkYear',
      onSelectPeriod: () {
        _showMonthYearPicker(
          target: 'SPK',
          currentMonth: _spkMonth,
          currentYear: _spkYear,
          onApply: (m, y) {
            setState(() {
              _spkMonth = m;
              _spkYear = y;
            });
            _fetchDashboardData();
          },
        );
      },
      onViewAll: () => context.push('/tracking-spk'),
      chips: [
        _buildChip(
          'OPEN: ${_spkStatusCounts['BELUM'] ?? 0}',
          bg: const Color(0xFFFEE2E2),
          border: const Color(0xFFFCA5A5),
          text: const Color(0xFFDC2626),
        ),
        _buildChip(
          'PROSES: ${_spkStatusCounts['PROSES'] ?? 0}',
          bg: const Color(0xFFFEF3C7),
          border: const Color(0xFFFCD34D),
          text: const Color(0xFFD97706),
        ),
        _buildChip(
          'CLOSE: ${_spkStatusCounts['SUDAH'] ?? 0}',
          bg: const Color(0xFFDCFCE7),
          border: const Color(0xFF86EFAC),
          text: const Color(0xFF16A34A),
        ),
      ],
      segmentedBar: _buildSegmentedBar([
        _Segment(
          count: _spkStatusCounts['BELUM'] ?? 0,
          color: const Color(0xFFEF4444),
        ),
        _Segment(
          count: _spkStatusCounts['PROSES'] ?? 0,
          color: const Color(0xFFF59E0B),
        ),
        _Segment(
          count: _spkStatusCounts['SUDAH'] ?? 0,
          color: const Color(0xFF10B981),
        ),
      ]),
      items: _recentSpk.map((spk) {
        final ord = spk.qty;
        final real = spk.realisasiTotal;
        final progress = ord > 0 ? (real / ord).clamp(0.0, 1.0) : 0.0;
        return _buildRecentItemBox(
          code: spk.noSpk,
          date: _formatItemDate(spk.tanggalSpk),
          customer: spk.namaBarang,
          detail: 'Realisasi: ${real.toInt()} / ${ord.toInt()}',
          status: spk.status.isEmpty ? 'OPEN' : spk.status,
          statusColor: const Color(0xFFDC2626),
          statusBg: const Color(0xFFFEE2E2),
          progress: progress,
          progressColor: const Color(0xFFEF4444),
        );
      }).toList(),
    );
  }

  // ── PERMANENT SIDEBAR UNTUK DESKTOP (Width: 260px)
  Widget _buildDesktopSidebar(dynamic user) {
    final initials = (user?.nama ?? 'U')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();

    final isKurir = user?.jabatan.toUpperCase() == 'KURIR';
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    final List<Map<String, dynamic>> menuCategories = isKurir
        ? [
            {
              'title': 'PENGIRIMAN & LAINNYA',
              'items': [
                {
                  'title': 'Pengiriman Kurir',
                  'icon': Icons.local_shipping_outlined,
                  'route': '/kurir',
                },
                {
                  'title': 'Ganti Password',
                  'icon': Icons.vpn_key_outlined,
                  'route': '/ganti-password',
                },
              ],
            },
          ]
        : [
            {
              'title': 'AKTIVITAS HARIAN',
              'items': [
                {
                  'title': 'Customer',
                  'icon': Icons.people_outline,
                  'route': '/customer',
                },
                {
                  'title': 'Achievement',
                  'icon': Icons.stars_outlined,
                  'route': '/achievement',
                },
                {
                  'title': 'Visit Plan',
                  'icon': Icons.calendar_today_outlined,
                  'route': '/visit-plan',
                },
                {
                  'title': 'Visit',
                  'icon': Icons.place_outlined,
                  'route': '/visit',
                },
              ],
            },
            {
              'title': 'PENJUALAN',
              'items': [
                {
                  'title': 'Permintaan Harga',
                  'icon': Icons.monetization_on_outlined,
                  'route': '/permintaan-harga',
                },
                {
                  'title': 'Penawaran',
                  'icon': Icons.receipt_outlined,
                  'route': '/penawaran',
                },
              ],
            },
            {
              'title': 'PELACAKAN & LAINNYA',
              'items': [
                {
                  'title': 'Tracking Penawaran',
                  'icon': Icons.push_pin_outlined,
                  'route': '/tracking-penawaran',
                },
                {
                  'title': 'Tracking MAP',
                  'icon': Icons.map_outlined,
                  'route': '/tracking-map',
                },
                {
                  'title': 'Tracking SPK',
                  'icon': Icons.assignment_outlined,
                  'route': '/tracking-spk',
                },
                {
                  'title': 'Potensi',
                  'icon': Icons.trending_up_outlined,
                  'route': '/potensi',
                },
                {
                  'title': 'Invoice Jatuh Tempo',
                  'icon': Icons.alarm_on_outlined,
                  'route': '/invoice-jatuh-tempo',
                },
              ],
            },
            {
              'title': 'PENGATURAN',
              'items': [
                {
                  'title': 'Ganti Password',
                  'icon': Icons.vpn_key_outlined,
                  'route': '/ganti-password',
                },
              ],
            },
          ];

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          // 1. Logo Branding Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Image.asset(
                  AppAssets.logo,
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: const Text(
                        'PlanToday',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      'v${ref.watch(versionProvider).currentVersion}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. User Profile Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user?.nama ?? 'User').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  tooltip: 'Keluar Akun',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),

          // 3. Navigation Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: [
                // Dashboard Home Active Tile
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    ),
                  ),
                  child: const ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.dashboard_rounded,
                      size: 20,
                      color: Color(0xFF4F46E5),
                    ),
                    title: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),

                ...menuCategories.map((cat) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                        child: Text(
                          cat['title'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...(cat['items'] as List).map<Widget>((item) {
                        final title = item['title'] as String;
                        int badgeCount = 0;
                        if (title == 'Permintaan Harga') {
                          badgeCount = _totalActivePH;
                        } else if (title == 'Penawaran') {
                          badgeCount = isManager
                              ? _unapprovedPenawaranCount
                              : _totalActivePenawaran;
                        } else if (title == 'Tracking Penawaran') {
                          badgeCount = _totalActivePenawaran;
                        } else if (title == 'Tracking SPK') {
                          badgeCount = _totalActiveSpk;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          child: InkWell(
                            onTap: () => context.push(item['route'] as String),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  if (badgeCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '$badgeCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),

          // 4. Footer: Keyboard shortcut guide button if web
          if (kIsWeb)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: InkWell(
                onTap: () => showShortcutGuide(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.screenshot_monitor_outlined,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pintasan Layar',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      Text(
                        '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── NAVIGATION RAIL UNTUK TABLET (Width: 68px)
  Widget _buildTabletNavigationRail(dynamic user) {
    final isKurir = user?.jabatan.toUpperCase() == 'KURIR';

    return Container(
      width: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo Mini
          Image.asset(
            AppAssets.logo,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Navigation Icons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildRailIconButton(
                  icon: Icons.dashboard_rounded,
                  tooltip: 'Dashboard',
                  isActive: true,
                  onTap: () {},
                ),
                if (isKurir) ...[
                  _buildRailIconButton(
                    icon: Icons.local_shipping_outlined,
                    tooltip: 'Pengiriman Kurir',
                    onTap: () => context.push('/kurir'),
                  ),
                ] else ...[
                  _buildRailIconButton(
                    icon: Icons.people_outline,
                    tooltip: 'Customer',
                    onTap: () => context.push('/customer'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.stars_outlined,
                    tooltip: 'Achievement',
                    onTap: () => context.push('/achievement'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.calendar_today_outlined,
                    tooltip: 'Visit Plan',
                    onTap: () => context.push('/visit-plan'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.place_outlined,
                    tooltip: 'Visit',
                    onTap: () => context.push('/visit'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.monetization_on_outlined,
                    tooltip: 'Permintaan Harga',
                    badgeCount: _totalActivePH,
                    onTap: () => context.push('/permintaan-harga'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.receipt_outlined,
                    tooltip: 'Penawaran',
                    badgeCount: _totalActivePenawaran,
                    onTap: () => context.push('/penawaran'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.assignment_outlined,
                    tooltip: 'Tracking SPK',
                    badgeCount: _totalActiveSpk,
                    onTap: () => context.push('/tracking-spk'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.trending_up_outlined,
                    tooltip: 'Potensi',
                    onTap: () => context.push('/potensi'),
                  ),
                  _buildRailIconButton(
                    icon: Icons.alarm_on_outlined,
                    tooltip: 'Invoice Jatuh Tempo',
                    onTap: () => context.push('/invoice-jatuh-tempo'),
                  ),
                ],
                _buildRailIconButton(
                  icon: Icons.vpn_key_outlined,
                  tooltip: 'Ganti Password',
                  onTap: () => context.push('/ganti-password'),
                ),
              ],
            ),
          ),

          // Bottom Actions
          if (kIsWeb)
            _buildRailIconButton(
              icon: Icons.keyboard_outlined,
              tooltip: 'Panduan Pintasan Keyboard',
              onTap: () => showShortcutGuide(context),
            ),
          _buildRailIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Keluar Akun (${(user?.nama ?? "").toUpperCase()})',
            iconColor: const Color(0xFFEF4444),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildRailIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    int badgeCount = 0,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : (iconColor ?? const Color(0xFF64748B)),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SKELETON DASHBOARD LOADING
  Widget _buildSkeletonDashboard() {
    return AnimatedBuilder(
      animation: _skeletonPulse,
      builder: (context, child) {
        return Opacity(
          opacity: _skeletonPulse.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Skeleton Visit Plan Card
              _buildSkeletonCard(
                children: [
                  Row(children: [_buildSkeletonBar(width: 140, height: 18)]),
                  const SizedBox(height: 14),
                  _buildSkeletonBar(
                    width: double.infinity,
                    height: 46,
                    radius: 14,
                  ),
                  const SizedBox(height: 14),
                  _buildSkeletonBar(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  _buildSkeletonBar(width: 220, height: 14),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Skeleton Achievement Card
              _buildSkeletonCard(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSkeletonBar(width: 150, height: 18),
                      _buildSkeletonBar(width: 50, height: 14),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSkeletonBar(width: 80, height: 12),
                              const SizedBox(height: 6),
                              _buildSkeletonBar(width: 110, height: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSkeletonBar(width: 80, height: 12),
                              const SizedBox(height: 6),
                              _buildSkeletonBar(width: 110, height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSkeletonBar(
                    width: double.infinity,
                    height: 8,
                    radius: 99,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Skeleton Module Card (PH / Penawaran / SPK style)
              _buildSkeletonCard(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSkeletonBar(width: 160, height: 18),
                      _buildSkeletonBar(width: 60, height: 14),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSkeletonBar(width: 120, height: 24, radius: 8),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSkeletonBar(width: 65, height: 22, radius: 8),
                      const SizedBox(width: 6),
                      _buildSkeletonBar(width: 65, height: 22, radius: 8),
                      const SizedBox(width: 6),
                      _buildSkeletonBar(width: 65, height: 22, radius: 8),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSkeletonBar(
                    width: double.infinity,
                    height: 6,
                    radius: 99,
                  ),
                  const SizedBox(height: 14),
                  _buildSkeletonBar(
                    width: double.infinity,
                    height: 64,
                    radius: 14,
                  ),
                  const SizedBox(height: 8),
                  _buildSkeletonBar(
                    width: double.infinity,
                    height: 64,
                    radius: 14,
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSkeletonBar({
    required double width,
    required double height,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── WIDGET HELPER: 3 KARTU QUICK STATS
  Widget _buildQuickStatCard({
    required String number,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fillHeight = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: fillHeight ? null : 84,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
          boxShadow: AppShadows.softCard,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Ambient Top Gradient Accent (Semburat warna halus di area atas yang memudar ke bawah)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 48,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.12),
                          color.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Micro Glow Accent Line di puncak atas kartu
              Positioned(
                left: 16,
                right: 16,
                top: 0,
                height: 2.0,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(99),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          color.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
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
    );
  }

  // ── WIDGET HELPER: AKSEN LINE SAMAR & TOP GLOW ELEGAN
  Widget _buildCardTopAccent({
    required Color accentColor,
    double height = 2.5,
    double horizontalInset = 32,
    double ambientHeight = 60,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Ambient Top Gradient Accent (Semburat halus di atas yang memudar ke bawah)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: ambientHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.08),
                      accentColor.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Micro Glow Accent Line di puncak atas kartu
            Positioned(
              left: horizontalInset,
              right: horizontalInset,
              top: 0,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(99),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accentColor.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGET HELPER: KARTU MODUL BER-STRIPE KIRI
  Widget _buildStripeModuleCard({
    required Color stripeColor,
    required String title,
    required String periodText,
    required VoidCallback onSelectPeriod,
    required VoidCallback onViewAll,
    required List<Widget> chips,
    required Widget segmentedBar,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Top Gradient Accent (Semburat warna halus di area header atas yang memudar ke bawah)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 100,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        stripeColor.withValues(alpha: 0.12),
                        stripeColor.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Micro Glow Accent Line di puncak atas kartu untuk sentuhan modern
            Positioned(
              left: 32,
              right: 32,
              top: 0,
              height: 2.5,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(99),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        stripeColor.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: onViewAll,
                        child: const Row(
                          children: [
                            Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Periode Pill Selector
                  Row(
                    children: [
                      const Text(
                        'Periode: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: onSelectPeriod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                periodText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
                                color: Color(0xFF4F46E5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chips Row
                  Row(
                    children: chips
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: c,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),

                  // Segmented Progress Bar
                  segmentedBar,
                  const SizedBox(height: 12),

                  // Item List
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada data terbaru.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    Column(children: items),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required Color bg,
    required Color border,
    required Color text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(List<_Segment> segments) {
    final total = segments.fold<int>(0, (acc, s) => acc + s.count);
    if (total == 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(99),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Row(
          children: segments.where((s) => s.count > 0).map((s) {
            return Expanded(
              flex: s.count,
              child: Container(color: s.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentItemBox({
    required String code,
    required String date,
    required String customer,
    required String detail,
    required String status,
    required Color statusColor,
    required Color statusBg,
    double? progress,
    Color? progressColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            customer,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressColor ?? const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SIDEBAR DRAWER MENU
  Widget _buildSidebarDrawer(dynamic user) {
    final initials = (user?.nama ?? 'U')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join('')
        .toUpperCase();

    final isKurir = user?.jabatan.toUpperCase() == 'KURIR';
    final isManager = user?.jabatan.toUpperCase() == 'MANAGER';

    final List<Map<String, dynamic>> menuCategories = isKurir
        ? [
            {
              'title': 'PENGIRIMAN & LAINNYA',
              'items': [
                {
                  'title': 'Pengiriman Kurir',
                  'icon': Icons.local_shipping_outlined,
                  'route': '/kurir',
                },
                {
                  'title': 'Ganti Password',
                  'icon': Icons.vpn_key_outlined,
                  'route': '/ganti-password',
                },
              ],
            },
          ]
        : [
            {
              'title': 'AKTIVITAS HARIAN',
              'items': [
                {
                  'title': 'Customer',
                  'icon': Icons.people_outline,
                  'route': '/customer',
                },
                {
                  'title': 'Achievement',
                  'icon': Icons.stars_outlined,
                  'route': '/achievement',
                },
                {
                  'title': 'Visit Plan',
                  'icon': Icons.calendar_today_outlined,
                  'route': '/visit-plan',
                },
                {
                  'title': 'Visit',
                  'icon': Icons.place_outlined,
                  'route': '/visit',
                },
              ],
            },
            {
              'title': 'PENJUALAN',
              'items': [
                {
                  'title': 'Permintaan Harga',
                  'icon': Icons.monetization_on_outlined,
                  'route': '/permintaan-harga',
                },
                {
                  'title': 'Penawaran',
                  'icon': Icons.receipt_outlined,
                  'route': '/penawaran',
                },
              ],
            },
            {
              'title': 'PELACAKAN & LAINNYA',
              'items': [
                {
                  'title': 'Tracking Penawaran',
                  'icon': Icons.push_pin_outlined,
                  'route': '/tracking-penawaran',
                },
                {
                  'title': 'Tracking MAP',
                  'icon': Icons.map_outlined,
                  'route': '/tracking-map',
                },
                {
                  'title': 'Tracking SPK',
                  'icon': Icons.assignment_outlined,
                  'route': '/tracking-spk',
                },
                {
                  'title': 'Potensi',
                  'icon': Icons.trending_up_outlined,
                  'route': '/potensi',
                },
                {
                  'title': 'Invoice Jatuh Tempo',
                  'icon': Icons.alarm_on_outlined,
                  'route': '/invoice-jatuh-tempo',
                },
              ],
            },
            {
              'title': 'PENGATURAN',
              'items': [
                {
                  'title': 'Ganti Password',
                  'icon': Icons.vpn_key_outlined,
                  'route': '/ganti-password',
                },
              ],
            },
          ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header Profil
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user?.nama ?? 'User').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user?.jabatan ?? "-"} · ${user?.cabang ?? "-"}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    tooltip: 'Keluar Akun',
                    onPressed: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),

            // Menu Items Grid
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: menuCategories.map((cat) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cat['title'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: (cat['items'] as List).map<Widget>((item) {
                          final title = item['title'] as String;
                          int badgeCount = 0;
                          if (title == 'Permintaan Harga') {
                            badgeCount = _totalActivePH;
                          } else if (title == 'Penawaran') {
                            badgeCount = isManager
                                ? _unapprovedPenawaranCount
                                : _totalActivePenawaran;
                          } else if (title == 'Tracking Penawaran') {
                            badgeCount = _totalActivePenawaran;
                          } else if (title == 'Tracking SPK') {
                            badgeCount = _totalActiveSpk;
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              context.push(item['route'] as String);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (badgeCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '$badgeCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Tombol Bantuan Pintasan (Web Only)
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(context);
                    showShortcutGuide(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shortcut_rounded,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cara Buat Pintasan di HP / PC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── KONFIRMASI KELUAR AKUN (Persis Detail React Native)
  void _confirmLogout(BuildContext context) {
    final user = ref.read(authProvider).user;
    final userName = (user?.nama ?? '').toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.12),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // modalIndicator (width: 44, height: 4, borderRadius: 2, marginBottom: 18)
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // modalTitle (fontSize: 18, fontWeight: '900', color: THEME.ink)
                const Text(
                  'Konfirmasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),

                // modalSubtitle (marginTop: 10, fontSize: 13, color: THEME.muted, textAlign: 'center')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Yakin ingin keluar?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),

                // modalUserName (marginTop: 6, fontSize: 14, fontWeight: '900', color: THEME.ink, letterSpacing: 0.6)
                if (userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),

                // modalActionRow (marginTop: 18, flexDirection: 'row', gap: 12)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    children: [
                      // btnCancel (flex: 1, paddingVertical: 12, borderRadius: 12, backgroundColor: '#EEF2F7')
                      Expanded(
                        child: Material(
                          color: const Color(0xFFEEF2F7),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(ctx),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // btnLogoutConfirm (flex: 1, paddingVertical: 12, borderRadius: 12, backgroundColor: THEME.danger)
                      Expanded(
                        child: Material(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref.read(authProvider.notifier).logout();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Keluar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment {
  final int count;
  final Color color;
  const _Segment({required this.count, required this.color});
}
