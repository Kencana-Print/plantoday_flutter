import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/potensi_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/potensi_repository.dart';
import 'modal_batal_potensi.dart';
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

const _kFullMonths = [
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

class LaporanPotensiScreen extends ConsumerStatefulWidget {
  const LaporanPotensiScreen({super.key});

  @override
  ConsumerState<LaporanPotensiScreen> createState() =>
      _LaporanPotensiScreenState();
}

class _LaporanPotensiScreenState extends ConsumerState<LaporanPotensiScreen> {
  final _searchController = TextEditingController();

  int _fromMonth = DateTime.now().month;
  int _fromYear = DateTime.now().year;
  int _toMonth = DateTime.now().month;
  int _toYear = DateTime.now().year;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  List<PotensiListItem> _rawItems = [];
  bool _isLoading = false;

  // Filter
  String _selectedStatus = 'ALL'; // ALL, POTENSI, CLOSE, BATAL
  String _selectedSales = '';
  List<String> _salesList = [];

  final List<String> _statusOptions = ['ALL', 'POTENSI', 'CLOSE', 'BATAL'];

  @override
  void initState() {
    super.initState();
    _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.isManager == true) {
        _loadSalesList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _periodeBulanLabel {
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month) {
      return '${_kFullMonths[_startDate.month - 1].toUpperCase()} ${_startDate.year}';
    } else if (_startDate.year == _endDate.year) {
      return '${_kShortMonths[_startDate.month - 1].toUpperCase()} - ${_kShortMonths[_endDate.month - 1].toUpperCase()} ${_startDate.year}';
    } else {
      return '${_kShortMonths[_startDate.month - 1].toUpperCase()} ${_startDate.year} - ${_kShortMonths[_endDate.month - 1].toUpperCase()} ${_endDate.year}';
    }
  }

  String _formatItemDate(String? ymd) {
    if (ymd == null || ymd.isEmpty) return '-';
    try {
      final clean = ymd.split('T')[0].split(' ')[0];
      final parts = clean.split('-').map(int.parse).toList();
      return '${parts[2]} ${_kShortMonths[parts[1] - 1]} ${parts[0]}';
    } catch (_) {
      return ymd;
    }
  }

  Future<void> _loadSalesList() async {
    try {
      final repo = ref.read(penawaranRepositoryProvider);
      final rows = await repo.getMasterSales('');
      if (mounted) {
        setState(() {
          _salesList = rows
              .map((e) => e['nama'] ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(potensiRepositoryProvider);
    final results = await repo.getPotensiList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      search: query ?? _searchController.text.trim(),
      sales: isManager && _selectedSales.isNotEmpty
          ? _selectedSales
          : (!isManager ? user?.nama : null),
    );

    if (mounted) {
      setState(() {
        _rawItems = results.list;
        if (_salesList.isEmpty && isManager) {
          final fromData =
              results.list
                  .map((e) => e.salesNama.trim())
                  .where((n) => n.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          if (fromData.isNotEmpty) _salesList = fromData;
        }
        _isLoading = false;
      });
    }
  }

  String _formatMonthYear(int m, int y) {
    if (m < 1 || m > 12) return '$m/$y';
    return '${_kShortMonths[m - 1]} $y';
  }

  void _applyPeriodRange(int fy, int fm, int ty, int tm) {
    final a = fy * 12 + fm;
    final b = ty * 12 + tm;

    final startYear = a <= b ? fy : ty;
    final startMonth = a <= b ? fm : tm;
    final endYear = a <= b ? ty : fy;
    final endMonth = a <= b ? tm : fm;

    setState(() {
      _fromYear = startYear;
      _fromMonth = startMonth;
      _toYear = endYear;
      _toMonth = endMonth;
      _startDate = DateTime(startYear, startMonth, 1);
      _endDate = DateTime(endYear, endMonth + 1, 0);
    });

    _fetchData();
  }

  void _showMonthYearPicker({required bool isStart}) {
    int tempMonth = isStart ? _fromMonth : _toMonth;
    int tempYear = isStart ? _fromYear : _toYear;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - 2 + i);

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
                    Text(
                      isStart ? 'Pilih Periode Awal' : 'Pilih Periode Akhir',
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
                            child: Text(
                              _kFullMonths[i],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                        items: years.map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(
                              y.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isStart) {
                        _applyPeriodRange(
                          tempYear,
                          tempMonth,
                          _toYear,
                          _toMonth,
                        );
                      } else {
                        _applyPeriodRange(
                          _fromYear,
                          _fromMonth,
                          tempYear,
                          tempMonth,
                        );
                      }
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
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

  void _showSalesPicker() {
    String searchKeyword = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _salesList.where((s) {
              return s.toLowerCase().contains(searchKeyword.toLowerCase());
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
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
                          'Pilih Sales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_selectedSales.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedSales = '');
                              Navigator.pop(ctx);
                              _fetchData();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setModalState(() => searchKeyword = val);
                              },
                              decoration: const InputDecoration(
                                hintText: 'Cari nama sales...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final sName = filtered[idx];
                          final isSelected = _selectedSales == sName;
                          return ListTile(
                            title: Text(
                              sName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF4F46E5),
                                  )
                                : null,
                            onTap: () {
                              setState(() => _selectedSales = sName);
                              Navigator.pop(ctx);
                              _fetchData();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isManager = user?.isManager ?? false;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Filter status & search
    final q = _searchController.text.trim().toLowerCase();
    final filteredList = _rawItems.where((it) {
      final s = it.status.toUpperCase();
      if (_selectedStatus != 'ALL') {
        if (_selectedStatus == 'POTENSI' && (s == 'CLOSE' || s == 'BATAL')) {
          return false;
        }
        if (_selectedStatus == 'CLOSE' && s != 'CLOSE') return false;
        if (_selectedStatus == 'BATAL' && s != 'BATAL') return false;
      }

      if (q.isNotEmpty) {
        final matchNomor = it.nomor.toLowerCase().contains(q);
        final matchCustomer = it.customerNama.toLowerCase().contains(q);
        final matchItem = it.namaItem.toLowerCase().contains(q);
        final matchSales = it.salesNama.toLowerCase().contains(q);
        return matchNomor || matchCustomer || matchItem || matchSales;
      }
      return true;
    }).toList();

    final totalNominalFiltered = filteredList.fold<double>(
      0.0,
      (acc, it) => acc + it.harga,
    );

    final String bannerTitle;
    final String bannerBadge;
    switch (_selectedStatus) {
      case 'POTENSI':
        bannerTitle = 'TOTAL POTENSI OMSET ($_periodeBulanLabel)';
        bannerBadge = '${filteredList.length} Item Aktif';
        break;
      case 'CLOSE':
        bannerTitle = 'TOTAL REALISASI CLOSE ($_periodeBulanLabel)';
        bannerBadge = '${filteredList.length} Item Close';
        break;
      case 'BATAL':
        bannerTitle = 'TOTAL OMSET BATAL ($_periodeBulanLabel)';
        bannerBadge = '${filteredList.length} Item Batal';
        break;
      default:
        bannerTitle = 'TOTAL KESELURUHAN OMSET ($_periodeBulanLabel)';
        bannerBadge = '${filteredList.length} Item';
    }

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
                    // 1. TOP HEADER (Persis React Native)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        0,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/potensi');
                              }
                            },
                            child: Container(
                              width: isDesktop ? 44 : 40,
                              height: isDesktop ? 44 : 40,
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
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: isDesktop ? 26 : 24,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Laporan Potensi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Tombol Shortcut Input Potensi
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFC7D2FE),
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => context.push('/potensi'),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: Color(0xFF4F46E5),
                              ),
                              label: const Text(
                                'Potensi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          AppReloadButton(
                            onTap: _fetchData,
                            isLoading: _isLoading,
                            tooltip: 'Segarkan laporan',
                            size: isDesktop ? 44 : 40,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. SUMMARY BANNER (Kartu Gradien Persis React Native)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    bannerTitle,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bannerBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormat.format(totalNominalFiltered),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. BAR FILTER TANGGAL, SEARCH, & SALES
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        children: [
                          // Row 1: Search Bar & Sales Filter (Khusus Manager)
                          Row(
                            children: [
                              // Search Input Box
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                        15,
                                        23,
                                        42,
                                        0.08,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (_) => setState(() {}),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Cari customer, nomor, item...',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      if (_searchController.text.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _searchController.clear(),
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isManager) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _showSalesPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 42,
                                    constraints: const BoxConstraints(
                                      maxWidth: 140,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedSales.isNotEmpty
                                            ? const Color(0xFF4F46E5)
                                            : const Color.fromRGBO(
                                                15,
                                                23,
                                                42,
                                                0.08,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 16,
                                          color: _selectedSales.isNotEmpty
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _selectedSales.isNotEmpty
                                                ? _selectedSales
                                                : 'Sales',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: _selectedSales.isNotEmpty
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Rentang Periode Awal & Periode Akhir (Sesuai Menu Achievement)
                          Row(
                            children: [
                              // Periode Awal
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Periode Awal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _showMonthYearPicker(isStart: true),
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color.fromRGBO(
                                              15,
                                              23,
                                              42,
                                              0.08,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatMonthYear(
                                                _fromMonth,
                                                _fromYear,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 16,
                                              color: Color(0xFF4F46E5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Periode Akhir
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Periode Akhir',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _showMonthYearPicker(isStart: false),
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color.fromRGBO(
                                              15,
                                              23,
                                              42,
                                              0.08,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatMonthYear(
                                                _toMonth,
                                                _toYear,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 16,
                                              color: Color(0xFF4F46E5),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 4. CHIP FILTER STATUS (ALL, POTENSI, CLOSE, BATAL)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusOptions.map((st) {
                          final isSelected = _selectedStatus == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(st),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedStatus = st);
                              },
                              selectedColor: const Color(0xFF4F46E5),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                    const SizedBox(height: 8),

                    // 5. DAFTAR KARTU LAPORAN
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : filteredList.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada laporan potensi pada periode ini.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : _buildAdaptiveList(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              horizontalPadding: horizontalPadding,
                              items: filteredList,
                              currencyFormat: currencyFormat,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdaptiveList({
    required bool isDesktop,
    required bool isTablet,
    required double horizontalPadding,
    required List<PotensiListItem> items,
    required NumberFormat currencyFormat,
  }) {
    final crossAxisCount = (isDesktop || isTablet) ? 2 : 1;

    if (crossAxisCount == 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          6,
          horizontalPadding,
          24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildReportCard(
          item: items[index],
          currencyFormat: currencyFormat,
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 220,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildReportCard(item: items[index], currencyFormat: currencyFormat),
    );
  }

  Widget _buildReportCard({
    required PotensiListItem item,
    required NumberFormat currencyFormat,
  }) {
    final status = item.status.toUpperCase();
    final isClose = status == 'CLOSE';
    final isBatal = status == 'BATAL';
    final isPotensi = !isClose && !isBatal;

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;

    if (isClose) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF15803D);
    } else if (isBatal) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeBorder = const Color(0xFFFCA5A5);
      badgeText = const Color(0xFFB91C1C);
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFFCD34D);
      badgeText = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Card (Nomor, Tanggal, Badge Status)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.nomor,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '•',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatItemDate(item.tanggal),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      isPotensi ? 'POTENSI' : status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: badgeText,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.nomorSumber != null &&
                  item.nomorSumber!.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final refNo = item.nomorSumber!.trim();
                    final upper = refNo.toUpperCase();
                    final isMap = upper.startsWith('MAP') ||
                        upper.startsWith('MSPK') ||
                        item.tipeSumber.toUpperCase() == 'MAP';
                    final isPen = !isMap ||
                        upper.startsWith('PEN') ||
                        upper.contains('/') ||
                        item.tipeSumber.toUpperCase() == 'PENAWARAN';

                    final targetRoute = isPen ? '/tracking-penawaran' : '/tracking-map';
                    final uri = Uri(
                      path: targetRoute,
                      queryParameters: {'q': refNo},
                    ).toString();

                    context.push(uri, extra: refNo);
                  },
                  child: Row(
                    children: [
                      Icon(
                        (item.nomorSumber!.toUpperCase().startsWith('PEN') ||
                                item.tipeSumber.toUpperCase() == 'PENAWARAN')
                            ? Icons.description_outlined
                            : Icons.map_outlined,
                        size: 13,
                        color: const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Ref: ${item.nomorSumber}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                item.customerNama.isNotEmpty ? item.customerNama : '-',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.namaItem.isNotEmpty ? item.namaItem : '-',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // Alasan Batal Box jika Status BATAL
          if (isBatal &&
              item.alasanBatal != null &&
              item.alasanBatal!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Batal: ${item.alasanBatal}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Footer (Sales, Harga, & Tombol Batalkan jika masih Potensi)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.salesNama.isNotEmpty)
                    Text(
                      'Sales: ${item.salesNama}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    currencyFormat.format(item.harga),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (isPotensi)
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final confirmed = await showModalBatalPotensi(
                        context,
                        item: item,
                        onConfirm: (alasan) async {
                          final repo = ref.read(potensiRepositoryProvider);
                          final ok = await repo.batalPotensi(
                            item.nomor,
                            alasan,
                          );
                          if (!mounted) return ok;
                          if (ok) {
                            AppToast.success(
                              context,
                              'Potensi ${item.nomor} berhasil dibatalkan',
                            );
                            _fetchData();
                            return true;
                          } else {
                            AppToast.error(
                              context,
                              'Gagal membatalkan potensi',
                            );
                            return false;
                          }
                        },
                      );
                      if (confirmed == true && mounted) {
                        _fetchData();
                      }
                    },
                    child: const Text(
                      'Batalkan',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
