import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/segmented_bar.dart';
import '../../widgets/app_reload_button.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class TrackingMapScreen extends ConsumerStatefulWidget {
  final String? initialSearch;

  const TrackingMapScreen({super.key, this.initialSearch});

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

  static List<String> splitNotes(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'\r?\n|\s*\|\s*|\s*;\s*|\s*•\s*'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  late final TextEditingController _searchController;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<TrackingMapListItem> _items = [];
  bool _isLoading = false;

  // Filter Status BAST & SJ MAP (Multi-select toggle persis React Native)
  bool _isFilterBast = false;
  bool _isFilterSjMap = false;

  // State Sales (Khusus Manager bisa pilih, non-manager terkunci)
  String _selectedSales = '';
  List<String> _salesList = [];

  // Set item yang sedang dibuka (Expand/Collapse accordion)
  final Set<String> _openedItemKeys = {};

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
  void didUpdateWidget(covariant TrackingMapScreen oldWidget) {
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

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingMapList(
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
          final fromData = results
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
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
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
                          const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
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
                            leading: const Icon(Icons.people_outline,
                                color: Color(0xFF4F46E5)),
                            title: const Text(
                              'Semua Sales',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            selected: _selectedSales.isEmpty,
                            trailing: _selectedSales.isEmpty
                                ? const Icon(Icons.check, color: Color(0xFF4F46E5))
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
                              leading: const Icon(Icons.person_outline,
                                  color: Color(0xFF64748B)),
                              title: Text(s,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              selected: isSel,
                              trailing: isSel
                                  ? const Icon(Icons.check,
                                      color: Color(0xFF4F46E5))
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

  // Hitung jumlah item dengan BAST dan SJ MAP
  int get _bastCount => _items.where((it) => it.tanggalBast.isNotEmpty).length;
  int get _sjMapCount => _items.where((it) => it.tanggalSjMap.isNotEmpty).length;

  // Logika filter multi-kondisi persis React Native
  List<TrackingMapListItem> get _filteredItems {
    return _items.where((item) {
      // 1. Keduanya aktif -> BAST harus ada & SJ MAP harus ada
      if (_isFilterBast && _isFilterSjMap) {
        return item.tanggalBast.isNotEmpty && item.tanggalSjMap.isNotEmpty;
      }
      // 2. Hanya BAST aktif -> BAST harus ada & SJ MAP harus kosong
      if (_isFilterBast) {
        return item.tanggalBast.isNotEmpty && item.tanggalSjMap.isEmpty;
      }
      // 3. Hanya SJ MAP aktif -> SJ MAP harus ada & BAST harus kosong
      if (_isFilterSjMap) {
        return item.tanggalSjMap.isNotEmpty && item.tanggalBast.isEmpty;
      }
      // 4. Keduanya tidak aktif -> tampilkan semua
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredItems;

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
                    // 1. TOP HEADER (Persis Tracking Penawaran)
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
                                  'Tracking MAP',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Pelacakan status BAST & Surat Jalan MAP',
                                  style: TextStyle(
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

                    // 2. SEARCH & FILTER CARD (Persis Tracking Penawaran)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                            // 1. Date Range Card Persis Tracking Penawaran (startDate -> arrow -> endDate)
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

                            // 2. Search Box Sesuai Standar Tracking Penawaran (Hanya Search Saat Enter)
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
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                            'Cari nomor MAP, customer, surat jalan...',
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

                            // 3. Filter Sales Full-Width (Sesuai Tracking Penawaran)
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

                            // 4. Status Filter Chips Row (Semua, BAST, SJ MAP)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                // Chip 1: Semua
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _isFilterBast = false;
                                        _isFilterSjMap = false;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (!_isFilterBast && !_isFilterSjMap)
                                                ? const Color(0xFF4F46E5)
                                                : const Color(0xFFEEF2FF),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              (!_isFilterBast && !_isFilterSjMap)
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFFC7D2FE),
                                          width:
                                              (!_isFilterBast && !_isFilterSjMap)
                                                  ? 1.4
                                                  : 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        'ALL (${_items.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              (!_isFilterBast && !_isFilterSjMap)
                                                  ? Colors.white
                                                  : const Color(0xFF4338CA),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Chip 2: BAST
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _isFilterBast = !_isFilterBast;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isFilterBast
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFECFDF5),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _isFilterBast
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFA7F3D0),
                                          width: _isFilterBast ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: _isFilterBast
                                                  ? Colors.white
                                                  : const Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'BAST ($_bastCount)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _isFilterBast
                                                  ? Colors.white
                                                  : const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Chip 3: SJ MAP
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _isFilterSjMap = !_isFilterSjMap;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isFilterSjMap
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _isFilterSjMap
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFBFDBFE),
                                          width: _isFilterSjMap ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: _isFilterSjMap
                                                  ? Colors.white
                                                  : const Color(0xFF3B82F6),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'SJ MAP ($_sjMapCount)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _isFilterSjMap
                                                  ? Colors.white
                                                  : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                            // 5. Segmented Bar Progress Distribution
                            SegmentedBar(
                              segments: [
                                SegmentItem(
                                  count: _bastCount,
                                  color: const Color(0xFF10B981),
                                ),
                                SegmentItem(
                                  count: _sjMapCount,
                                  color: const Color(0xFF3B82F6),
                                ),
                                SegmentItem(
                                  count:
                                      (_items.length - _bastCount - _sjMapCount) >
                                              0
                                          ? (_items.length -
                                              _bastCount -
                                              _sjMapCount)
                                          : 0,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ],
                              height: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. DAFTAR KARTU ACCORDION TRACKING MAP
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : displayList.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Data tracking MAP tidak ditemukan.',
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
                                          items: displayList,
                                          horizontalPadding: horizontalPadding,
                                        )
                                      : ListView.separated(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: horizontalPadding,
                                            vertical: 6,
                                          ),
                                          itemCount: displayList.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final item = displayList[index];
                                            final key =
                                                '${item.noMap}-${item.tanggalMap}-$index';
                                            final isOpened =
                                                _openedItemKeys.contains(key);

                                            return _TrackingMapRowCard(
                                              item: item,
                                              isOpened: isOpened,
                                              onToggle: () {
                                                setState(() {
                                                  if (isOpened) {
                                                    _openedItemKeys.remove(key);
                                                  } else {
                                                    _openedItemKeys.add(key);
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

  // Tampilan 2 kolom berdampingan untuk Tablet / Desktop
  Widget _buildAdaptiveGrid({
    required List<TrackingMapListItem> items,
    required double horizontalPadding,
  }) {
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final key = '${item.noMap}-${item.tanggalMap}-$i';
      final isOpened = _openedItemKeys.contains(key);

      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _TrackingMapRowCard(
          item: item,
          isOpened: isOpened,
          onToggle: () {
            setState(() {
              if (isOpened) {
                _openedItemKeys.remove(key);
              } else {
                _openedItemKeys.add(key);
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
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 6,
      ),
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

class _TrackingMapRowCard extends StatelessWidget {
  final TrackingMapListItem item;
  final bool isOpened;
  final VoidCallback onToggle;

  const _TrackingMapRowCard({
    required this.item,
    required this.isOpened,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final notes = TrackingMapScreen.splitNotes(item.mspkKeterangan);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpened
              ? const Color(0xFF4F46E5)
              : const Color.fromRGBO(15, 23, 42, 0.08),
          width: isOpened ? 1.4 : 1.0,
        ),
        boxShadow: isOpened ? AppShadows.card : AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card (No MAP, Tanggal MAP, Chevron)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.noMap,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4F46E5),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TrackingMapScreen.formatDate(item.tanggalMap),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.customer.isNotEmpty ? item.customer : '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (item.alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.alamat,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isOpened
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isOpened
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isOpened
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Baris Status BAST & Surat Jalan
          Row(
            children: [
              // Kolom BAST
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.tanggalBast.isNotEmpty
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.tanggalBast.isNotEmpty
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BAST',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.tanggalBast.isNotEmpty
                            ? TrackingMapScreen.formatDate(item.tanggalBast)
                            : 'Belum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: item.tanggalBast.isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Kolom SJ MAP
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.tanggalSjMap.isNotEmpty
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.tanggalSjMap.isNotEmpty
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Surat Jalan',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.tanggalSjMap.isNotEmpty
                            ? TrackingMapScreen.formatDate(item.tanggalSjMap)
                            : 'Belum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: item.tanggalSjMap.isNotEmpty
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Dropdown Body (Collapsible Accordion Persis React Native)
          if (isOpened) ...[
            const SizedBox(height: 12),
            Container(
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
                  _buildSpecRow('Nama', item.mspkNama),
                  _buildSpecRow('Ukuran', item.mspkUkuran),
                  _buildSpecRow('Kain', item.mspkKain),
                  _buildSpecRow('Finishing', item.mspkFinishing),
                  if (item.nomorSj.isNotEmpty)
                    _buildSpecRow('No. SJ', item.nomorSj),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  const Text(
                    'Keterangan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (notes.isNotEmpty) ...[
                    ...notes.map((note) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ',
                                  style: TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12)),
                              Expanded(
                                child: Text(
                                  note,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ] else
                    const Text(
                      '-',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
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
