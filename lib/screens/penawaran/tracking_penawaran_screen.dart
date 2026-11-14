import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/segmented_bar.dart';
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

class TrackingPenawaranScreen extends ConsumerStatefulWidget {
  final String? initialSearch;

  const TrackingPenawaranScreen({super.key, this.initialSearch});

  @override
  ConsumerState<TrackingPenawaranScreen> createState() =>
      _TrackingPenawaranScreenState();
}

class _TrackingPenawaranScreenState
    extends ConsumerState<TrackingPenawaranScreen> {
  late final TextEditingController _searchController;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  List<TrackingPenawaranListItem> _items = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL'; // ALL, OPEN, PARSIAL, CLOSE

  // State Sales (Khusus Manager bisa pilih, non-manager terkunci)
  String _selectedSales = '';
  List<String> _salesList = [];

  // Detail MAP by No Penawaran (Cache & Expand/Collapse state persis React Native)
  String? _openedNoPenawaran;
  final Map<String, List<TrackingMapDetailItem>> _detailMapByPenawaran = {};
  final Set<String> _loadingDetailPenawaran = {};

  final List<String> _statusFilters = ['ALL', 'OPEN', 'PARSIAL', 'CLOSE'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch?.trim() ?? '';
    _searchController = TextEditingController(text: initial);
    if (initial.isNotEmpty) {
      _startDate = DateTime(DateTime.now().year - 1, 1, 1);
      _endDate = DateTime(DateTime.now().year + 1, 12, 31);
    }
    _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.isManager == true) {
        _loadSalesList();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrackingPenawaranScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != oldWidget.initialSearch) {
      final newSearch = widget.initialSearch?.trim() ?? '';
      _searchController.text = newSearch;
      if (newSearch.isNotEmpty) {
        _startDate = DateTime(DateTime.now().year - 1, 1, 1);
        _endDate = DateTime(DateTime.now().year + 1, 12, 31);
      }
      _fetchData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) =>
      '${d.day} ${_kShortMonths[d.month - 1]} ${d.year}';

  static String formatDate(String? ymd) {
    if (ymd == null || ymd.trim().isEmpty) return '-';
    try {
      final clean = ymd.trim().split('T')[0].split(' ')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12) {
          return '$d ${_kShortMonths[m - 1]} $y';
        }
      }
      final dt = DateTime.parse(clean);
      return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return ymd;
    }
  }

  static String getDocTypeLabel(String? docNo) {
    final cleanList = (docNo ?? '')
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (cleanList.isEmpty) return 'No. MAP';
    final first = cleanList[0].toUpperCase();
    if (first.startsWith('MAP')) return 'No. MAP';
    if (first.startsWith('SO')) return 'No. SO';
    return 'No. SPK';
  }

  static List<String> splitNotes(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'\r?\n|\s*\|\s*|\s*;\s*|\s*•\s*'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  static String toReadableDivisi(int? value) {
    if (value == 1) return '1 - SPANDUK';
    if (value == 4) return '4 - GARMEN';
    if (value == 5) return '5 - MMT';
    return value != null ? '$value' : '-';
  }

  static String toReadableCloseStatus(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v == 'Y') return 'Sudah';
    if (v == 'N') return 'Belum';
    return '-';
  }

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingPenawaranList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      search: query ?? _searchController.text.trim(),
      sales: isManager && _selectedSales.isNotEmpty
          ? _selectedSales
          : (!isManager ? user?.nama : null),
    );

    if (mounted) {
      setState(() {
        _items = results;
        if (_salesList.isEmpty && isManager) {
          final fromData =
              results
                  .map((e) => e.sales.trim())
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

  Future<void> _loadMapDetails(String noPenawaran) async {
    if (noPenawaran.isEmpty || _detailMapByPenawaran.containsKey(noPenawaran)) {
      return;
    }

    setState(() => _loadingDetailPenawaran.add(noPenawaran));

    final repo = ref.read(trackingRepositoryProvider);
    final details = await repo.getTrackingPenawaranDetail(noPenawaran);

    if (mounted) {
      setState(() {
        _detailMapByPenawaran[noPenawaran] = details;
        _loadingDetailPenawaran.remove(noPenawaran);
      });
      if (details.isEmpty) {
        AppToast.info(context, 'Detail MAP tidak ditemukan atau belum ada.');
      }
    }
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                              decoration: const InputDecoration(
                                hintText: 'Cari sales...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setModalState(() => searchKeyword = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.people_outline,
                              color: Color(0xFF4F46E5),
                            ),
                            title: const Text(
                              'Semua Sales',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            selected: _selectedSales.isEmpty,
                            trailing: _selectedSales.isEmpty
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF4F46E5),
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedSales = '';
                              });
                              _fetchData();
                            },
                          ),
                          const Divider(height: 1),
                          ...filtered.map((s) {
                            final isSel = _selectedSales == s;
                            return ListTile(
                              leading: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF64748B),
                              ),
                              title: Text(
                                s,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              selected: isSel,
                              trailing: isSel
                                  ? const Icon(
                                      Icons.check,
                                      color: Color(0xFF4F46E5),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedSales = s;
                                });
                                _fetchData();
                              },
                            );
                          }),
                        ],
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
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _items.where((i) => i.statusTracking == 'OPEN').length;
    final parsialCount = _items
        .where((i) => i.statusTracking == 'PARSIAL')
        .length;
    final closeCount = _items.where((i) => i.statusTracking == 'CLOSE').length;

    final trackingSegments = [
      SegmentItem(count: openCount, color: const Color(0xFFEF4444)),
      SegmentItem(count: parsialCount, color: const Color(0xFF3B82F6)),
      SegmentItem(count: closeCount, color: const Color(0xFF10B981)),
    ];

    final filteredItems = _items.where((it) {
      if (_selectedStatus != 'ALL') {
        return it.statusTracking == _selectedStatus;
      }
      return true;
    }).toList();

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
                                context.go('/home');
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
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Tracking Penawaran',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pelacakan konversi penawaran ke MAP',
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
                            onTap: () => _fetchData(),
                            isLoading: _isLoading,
                            tooltip: 'Segarkan data',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. SEARCH & FILTER CARD (Sesuai RN filterCard)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: AppShadows.softCard,
                        ),
                        child: Column(
                          children: [
                            // Date Range Card Persis RN (startDate -> arrow -> endDate)
                            InkWell(
                              onTap: _selectDateRange,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
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
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatDisplayDate(_startDate),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatDisplayDate(_endDate),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Search Box Sesuai Standar Tracking MAP (Hanya Search Saat Enter)
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
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
                                      textInputAction: TextInputAction.search,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Cari penawaran, customer, sales...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (q) => _fetchData(q),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _searchController.clear();
                                        _fetchData('');
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Filter Sales (Manager bisa pilih, Non-Manager terkunci)
                            Builder(
                              builder: (context) {
                                final user = ref.watch(authProvider).user;
                                final isManager = user?.isManager ?? false;
                                final displayName = isManager
                                    ? (_selectedSales.isEmpty
                                          ? 'Semua Sales'
                                          : _selectedSales)
                                    : (user?.nama.isNotEmpty == true
                                          ? user!.nama
                                          : 'Sales');

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: isManager ? _showSalesPicker : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isManager && _selectedSales.isNotEmpty
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            isManager &&
                                                _selectedSales.isNotEmpty
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
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 16,
                                          color:
                                              isManager &&
                                                  _selectedSales.isNotEmpty
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isManager &&
                                                      _selectedSales.isNotEmpty
                                                  ? const Color(0xFF4F46E5)
                                                  : (isManager
                                                        ? const Color(
                                                            0xFF0F172A,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          )),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isManager &&
                                            _selectedSales.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              setState(
                                                () => _selectedSales = '',
                                              );
                                              _fetchData();
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          )
                                        else if (isManager)
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 18,
                                            color: Color(0xFF64748B),
                                          )
                                        else
                                          const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 14,
                                            color: Color(0xFF94A3B8),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),

                            // Chip Filters Row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _statusFilters.map((st) {
                                final isSelected = _selectedStatus == st;
                                String countLabel = '';
                                if (st == 'OPEN') countLabel = ' ($openCount)';
                                if (st == 'PARSIAL') {
                                  countLabel = ' ($parsialCount)';
                                }
                                if (st == 'CLOSE') {
                                  countLabel = ' ($closeCount)';
                                }

                                Color baseColor = const Color(0xFF4F46E5);
                                Color unselectedBg = const Color(0xFFEEF2FF);
                                Color unselectedBorder = const Color(
                                  0xFFC7D2FE,
                                );
                                Color unselectedText = const Color(0xFF4338CA);

                                if (st == 'OPEN') {
                                  baseColor = const Color(0xFFEF4444);
                                  unselectedBg = const Color(0xFFFEF2F2);
                                  unselectedBorder = const Color(0xFFFECACA);
                                  unselectedText = const Color(0xFFDC2626);
                                } else if (st == 'PARSIAL') {
                                  baseColor = const Color(0xFF3B82F6);
                                  unselectedBg = const Color(0xFFEFF6FF);
                                  unselectedBorder = const Color(0xFFBFDBFE);
                                  unselectedText = const Color(0xFF1D4ED8);
                                } else if (st == 'CLOSE') {
                                  baseColor = const Color(0xFF10B981);
                                  unselectedBg = const Color(0xFFECFDF5);
                                  unselectedBorder = const Color(0xFFA7F3D0);
                                  unselectedText = const Color(0xFF059669);
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _selectedStatus = st),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? baseColor
                                            : unselectedBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? baseColor
                                              : unselectedBorder,
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (st != 'ALL') ...[
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.white
                                                    : baseColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Text(
                                            '$st$countLabel',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected
                                                  ? Colors.white
                                                  : unselectedText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),

                            // Segmented Bar Progress Distribution
                            SegmentedBar(segments: trackingSegments, height: 6),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. DAFTAR KARTU ACCORDION TRACKING PENAWARAN
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : filteredItems.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada data penawaran pada periode ini.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF4F46E5),
                              onRefresh: () => _fetchData(),
                              child: isDesktop || isTablet
                                  ? _buildAdaptiveGrid(
                                      items: filteredItems,
                                      horizontalPadding: horizontalPadding,
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                        vertical: 6,
                                      ),
                                      itemCount: filteredItems.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = filteredItems[index];
                                        final isOpened =
                                            _openedNoPenawaran ==
                                            item.noPenawaran;

                                        return _TrackingPenawaranRowCard(
                                          item: item,
                                          isOpened: isOpened,
                                          mapDetails:
                                              _detailMapByPenawaran[item
                                                  .noPenawaran],
                                          isLoadingDetail:
                                              _loadingDetailPenawaran.contains(
                                                item.noPenawaran,
                                              ),
                                          onToggle: () {
                                            setState(() {
                                              if (isOpened) {
                                                _openedNoPenawaran = null;
                                              } else {
                                                _openedNoPenawaran =
                                                    item.noPenawaran;
                                                _loadMapDetails(
                                                  item.noPenawaran,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      },
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
    );
  }

  Widget _buildAdaptiveGrid({
    required List<TrackingPenawaranListItem> items,
    required double horizontalPadding,
  }) {
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isOpened = _openedNoPenawaran == item.noPenawaran;

      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _TrackingPenawaranRowCard(
          item: item,
          isOpened: isOpened,
          mapDetails: _detailMapByPenawaran[item.noPenawaran],
          isLoadingDetail: _loadingDetailPenawaran.contains(item.noPenawaran),
          onToggle: () {
            setState(() {
              if (isOpened) {
                _openedNoPenawaran = null;
              } else {
                _openedNoPenawaran = item.noPenawaran;
                _loadMapDetails(item.noPenawaran);
              }
            });
          },
        ),
      );

      if (i % 2 == 0) {
        col1.add(cardWidget);
      } else {
        col2.add(cardWidget);
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: col1)),
          const SizedBox(width: 14),
          Expanded(child: Column(children: col2)),
        ],
      ),
    );
  }
}

// ── KARTU ACCORDION PERSIS REACT NATIVE `TrackingPenawaranRow`
class _TrackingPenawaranRowCard extends StatelessWidget {
  final TrackingPenawaranListItem item;
  final bool isOpened;
  final List<TrackingMapDetailItem>? mapDetails;
  final bool isLoadingDetail;
  final VoidCallback onToggle;

  const _TrackingPenawaranRowCard({
    required this.item,
    required this.isOpened,
    this.mapDetails,
    this.isLoadingDetail = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final status = item.statusTracking.toUpperCase();
    final isClose = status == 'CLOSE';
    final isParsial = status == 'PARSIAL';

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String badgeLabel;

    if (isClose) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF047857);
      badgeLabel = 'CLOSE';
    } else if (isParsial) {
      final pct = item.totalItem > 0
          ? ((item.totalItemMap / item.totalItem) * 100).round()
          : 0;
      badgeBg = const Color(0xFFDBEAFE);
      badgeBorder = const Color(0xFF93C5FD);
      badgeText = const Color(0xFF1D4ED8);
      badgeLabel = 'PARSIAL ($pct%)';
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeBorder = const Color(0xFFFCA5A5);
      badgeText = const Color(0xFFB91C1C);
      badgeLabel = 'OPEN';
    }

    final totalItem = item.totalItem;
    final totalItemMap = item.totalItemMap;
    final progressFraction = totalItem > 0
        ? (totalItemMap / totalItem).clamp(0.0, 1.0)
        : 0.0;

    String statusDescription;
    if (isClose) {
      statusDescription =
          'Seluruh item ($totalItemMap/$totalItem) sudah diproses menjadi MAP/SO/SPK';
    } else if (isParsial) {
      statusDescription =
          '$totalItemMap dari $totalItem item telah diproses menjadi MAP/SO/SPK';
    } else {
      statusDescription =
          'Belum ada item ($totalItemMap/$totalItem) yang diproses menjadi MAP/SO/SPK';
    }

    final docLabel = _TrackingPenawaranScreenState.getDocTypeLabel(item.noMap);

    return AppCard(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card: No Penawaran & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.noPenawaran.isNotEmpty ? item.noPenawaran : '-',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Nama Customer
          Row(
            children: [
              const Icon(
                Icons.business_rounded,
                size: 13,
                color: Color(0xFF0F172A),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.customer.isNotEmpty ? item.customer : '-',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Sales & Tanggal
          Row(
            children: [
              Text(
                'Sales: ${item.sales.isNotEmpty ? item.sales : '-'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '•',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 6),
              Text(
                _TrackingPenawaranScreenState.formatDate(item.tanggalPenawaran),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar & Deskripsi Status
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(badgeBorder),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusDescription,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          // List No MAP (jika ada)
          if (item.noMap.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(15, 23, 42, 0.06),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$docLabel: ',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.noMap,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Footer: Toggle Buka/Tutup Detail
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isOpened
                      ? 'Tutup detail item ${docLabel.replaceFirst("No. ", "")}'
                      : 'Lihat detail item ${docLabel.replaceFirst("No. ", "")}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isOpened
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: const Color(0xFF4F46E5),
              ),
            ],
          ),

          // Dropdown Body Detail MAP (Saat dibuka persis React Native)
          if (isOpened) ...[
            const SizedBox(height: 10),
            if (isLoadingDetail)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              )
            else if (mapDetails == null || mapDetails!.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Belum ada detail ${docLabel.replaceFirst("No. ", "")}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...mapDetails!.asMap().entries.map((entry) {
                final idx = entry.key;
                final map = entry.value;
                final notes = _TrackingPenawaranScreenState.splitNotes(
                  map.mapKeterangan,
                );

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${idx + 1}. ${map.noMap.isNotEmpty ? map.noMap : "${docLabel.replaceFirst("No. ", "")} belum tersedia"}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSpecRow('Nama', map.mapNama),
                      _buildSpecRow(
                        'Tanggal',
                        _TrackingPenawaranScreenState.formatDate(
                          map.tanggalMap,
                        ),
                      ),
                      _buildSpecRow(
                        'Deadline',
                        _TrackingPenawaranScreenState.formatDate(
                          map.mapDeadline,
                        ),
                      ),
                      _buildSpecRow(
                        'Divisi',
                        _TrackingPenawaranScreenState.toReadableDivisi(
                          map.mapDivisi,
                        ),
                      ),
                      _buildSpecRow('Status Proses', map.mapStatus),
                      _buildSpecRow(
                        'Status Close',
                        _TrackingPenawaranScreenState.toReadableCloseStatus(
                          map.mapClose,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Catatan:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                        ...notes.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '•  ',
                                  style: TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    n,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
