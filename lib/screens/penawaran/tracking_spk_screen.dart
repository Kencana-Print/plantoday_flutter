import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/tracking_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/segmented_bar.dart';
import '../../widgets/app_reload_button.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

class TrackingSpkScreen extends ConsumerStatefulWidget {
  const TrackingSpkScreen({super.key});

  @override
  ConsumerState<TrackingSpkScreen> createState() => _TrackingSpkScreenState();
}

class _TrackingSpkScreenState extends ConsumerState<TrackingSpkScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  List<TrackingSpkListItem> _items = [];
  bool _isLoading = false;
  String _selectedStatus = 'all'; // 'all', 'belum', 'proses', 'sudah'

  // Set card yang sedang dibuka (Expandable Accordion persis React Native)
  final Set<String> _openedItemKeys = {};

  final List<Map<String, dynamic>> _statusFilters = [
    {'key': 'all', 'label': 'Semua', 'color': Color(0xFF4F46E5)},
    {'key': 'belum', 'label': 'Open', 'color': Color(0xFFEF4444)},
    {'key': 'proses', 'label': 'Proses', 'color': Color(0xFFF59E0B)},
    {'key': 'sudah', 'label': 'Close', 'color': Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _fetchData([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(trackingRepositoryProvider);
    final results = await repo.getTrackingSpkList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _items = results;
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
      _fetchData();
    }
  }

  // Hitung jumlah item berdasarkan realisasi order (Persis React Native)
  int get _belumCount => _items.where((it) => it.realisasiTotal < 0.01).length;
  int get _sudahCount =>
      _items.where((it) => it.realisasiTotal >= (it.qty - 0.01) && it.qty > 0).length;
  int get _prosesCount => _items.where((it) {
        final r = it.realisasiTotal;
        final q = it.qty;
        return r >= 0.01 && r < (q - 0.01);
      }).length;

  List<TrackingSpkListItem> get _filteredItems {
    return _items.where((item) {
      if (_selectedStatus == 'all') return true;
      final order = item.qty;
      final realisasi = item.realisasiTotal;
      if (_selectedStatus == 'belum') return realisasi < 0.01;
      if (_selectedStatus == 'sudah') return realisasi >= order - 0.01;
      if (_selectedStatus == 'proses') {
        return realisasi >= 0.01 && realisasi < order - 0.01;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spkSegments = [
      SegmentItem(count: _belumCount, color: const Color(0xFFEF4444)),
      SegmentItem(count: _prosesCount, color: const Color(0xFFF59E0B)),
      SegmentItem(count: _sudahCount, color: const Color(0xFF10B981)),
    ];

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
                                  'Tracking SPK',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Periode ${_formatDisplayDate(_startDate)} - ${_formatDisplayDate(_endDate)}',
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

                    // 2. SEARCH & FILTER CARD (Persis React Native)
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
                            // Date Range Card Persis RN (startDate -> arrow -> endDate)
                            InkWell(
                              onTap: _selectDateRange,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color.fromRGBO(
                                        15, 23, 42, 0.08),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 6),
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

                            // Search Box Sesuai Standar Tracking (Hanya Search Saat Enter)
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.06),
                                ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded,
                                      size: 18, color: Color(0xFF64748B)),
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
                                        hintText: 'Cari SPK...',
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

                            // Chip Filters Row (Semua, Open, Proses, Close) Persis RN
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _statusFilters.map((f) {
                                  final key = f['key'] as String;
                                  final label = f['label'] as String;
                                  final dotColor = f['color'] as Color;
                                  final isActive = _selectedStatus == key;

                                  String countText = '';
                                  if (key == 'all') {
                                    countText = ' (${_items.length})';
                                  } else if (key == 'belum') {
                                    countText = ' ($_belumCount)';
                                  } else if (key == 'proses') {
                                    countText = ' ($_prosesCount)';
                                  } else if (key == 'sudah') {
                                    countText = ' ($_sudahCount)';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          setState(() => _selectedStatus = key),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFFEEF2FF)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF4F46E5)
                                                : const Color.fromRGBO(
                                                    15, 23, 42, 0.08),
                                            width: isActive ? 1.4 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (key == 'all') ...[
                                              Icon(
                                                Icons.format_list_bulleted,
                                                size: 14,
                                                color: isActive
                                                    ? const Color(0xFF4F46E5)
                                                    : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 6),
                                            ] else ...[
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: dotColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              '$label$countText',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: isActive
                                                    ? const Color(0xFF4F46E5)
                                                    : const Color(0xFF64748B),
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
                            SegmentedBar(segments: spkSegments, height: 6),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. DAFTAR KARTU ACCORDION TRACKING SPK
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
                                    'Data tracking SPK tidak ditemukan.',
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
                                                '${item.noSpk}-${item.tanggalSpk}-$index';
                                            final isOpened =
                                                _openedItemKeys.contains(key);

                                            return _TrackingSpkRowCard(
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
    required List<TrackingSpkListItem> items,
    required double horizontalPadding,
  }) {
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final key = '${item.noSpk}-${item.tanggalSpk}-$i';
      final isOpened = _openedItemKeys.contains(key);

      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _TrackingSpkRowCard(
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

// ── KARTU ACCORDION PERSIS REACT NATIVE `TrackingSpkRow`
class _TrackingSpkRowCard extends StatelessWidget {
  final TrackingSpkListItem item;
  final bool isOpened;
  final VoidCallback onToggle;

  const _TrackingSpkRowCard({
    required this.item,
    required this.isOpened,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final order = item.qty;
    final realisasi = item.realisasiTotal;

    // Evaluasi status persis RN getSpkStatus()
    Color badgeColor;
    Color badgeBg;
    String statusLabel;
    if (realisasi < 0.01) {
      badgeColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.08);
      statusLabel = 'OPEN';
    } else if (realisasi >= order - 0.01 && order > 0) {
      badgeColor = const Color(0xFF10B981);
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.08);
      statusLabel = 'CLOSE';
    } else {
      badgeColor = const Color(0xFFF59E0B);
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.08);
      statusLabel = 'PROSES';
    }

    final progressPct = order > 0 ? (realisasi / order).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (No SPK, Nama Pekerjaan di kiri; Detail & Status di kanan; Chevron)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SPK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.noSpk.isNotEmpty ? item.noSpk : '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.namaBarang.isNotEmpty ? item.namaBarang : '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Kolom Kanan (Aksi & Toggle Hint)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'DETAIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOpened ? 'Tap untuk tutup' : 'Tap untuk buka',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOpened
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron Indikator
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(
                  isOpened
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isOpened
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Meta Row: Tanggal SPK & Order
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Tanggal SPK: ',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: _TrackingSpkScreenState.formatDate(item.tanggalSpk),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Order: ${order.toInt()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar Realisasi
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progressPct,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),

          // Dropdown Body (Rincian 3 Blok Persis React Native saat dibuka)
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
                  // 1. Estimasi (Jadwal Kirim)
                  _buildSectionHeader('Estimasi (Jadwal Kirim)'),
                  const SizedBox(height: 4),
                  if (item.estimasiList.isNotEmpty) ...[
                    ...item.estimasiList.map(
                      (est) => _buildScheduleRow(
                        _TrackingSpkScreenState.formatDate(est.tanggal),
                        est.jumlah.toInt().toString(),
                      ),
                    ),
                    _buildTotalRow(
                        'Total Estimasi:', item.estimasiTotal.toInt().toString()),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '-',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 2. Komitmen (PPIC)
                  _buildSectionHeader('Komitmen (PPIC)'),
                  const SizedBox(height: 4),
                  if (item.komitmenList.isNotEmpty) ...[
                    ...item.komitmenList.map(
                      (kom) => _buildScheduleRow(
                        _TrackingSpkScreenState.formatDate(kom.tanggal),
                        kom.jumlah.toInt().toString(),
                      ),
                    ),
                    _buildTotalRow(
                        'Total Komitmen:', item.komitmenTotal.toInt().toString()),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '-',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 3. Realisasi (Surat Jalan)
                  _buildSectionHeader('Realisasi (Surat Jalan)'),
                  const SizedBox(height: 4),
                  if (item.realisasiList.isNotEmpty) ...[
                    ...item.realisasiList.map(
                      (real) => _buildScheduleRow(
                        _TrackingSpkScreenState.formatDate(real.tanggal),
                        real.jumlah.toInt().toString(),
                      ),
                    ),
                    _buildTotalRow('Total Realisasi:',
                        item.realisasiTotal.toInt().toString()),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '-',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildScheduleRow(String date, String qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('• ',
                  style: TextStyle(
                      color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            qty,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}
