import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/permintaan_harga_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/permintaan_harga_repository.dart';
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
    if (trimmed.contains('/')) {
      final parts = trimmed.split(' ')[0].split('/').map(int.parse).toList();
      if (parts.length >= 3) {
        final day = parts[0];
        final month = parts[1];
        final year = parts[2];
        if (month >= 1 && month <= 12) {
          return '$day ${_kShortMonths[month - 1]} $year';
        }
      }
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${parsed.day} ${_kShortMonths[parsed.month - 1]} ${parsed.year}';
    }
  } catch (_) {}
  return trimmed;
}

class PermintaanHargaListScreen extends ConsumerStatefulWidget {
  const PermintaanHargaListScreen({super.key});

  @override
  ConsumerState<PermintaanHargaListScreen> createState() =>
      _PermintaanHargaListScreenState();
}

class _PermintaanHargaListScreenState
    extends ConsumerState<PermintaanHargaListScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  List<PermintaanHargaItem> _list = [];
  bool _isLoading = false;
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL',
    'BELUM DIVERIFIKASI',
    'MINTA',
    'WAIT',
    'DONE',
    'BELUM',
    'NEGO',
    'CANCEL',
  ];

  bool _showTooltip = true;
  Timer? _tooltipTimer;

  @override
  void initState() {
    super.initState();
    _fetchList();
    _tooltipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _showTooltip) {
        setState(() => _showTooltip = false);
      }
    });
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _dismissTooltip() {
    _tooltipTimer?.cancel();
    if (_showTooltip) {
      setState(() => _showTooltip = false);
    }
  }

  void _showStatusLegendDialog() {
    _dismissTooltip();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Info Status Permintaan Harga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...['BELUM DIVERIFIKASI', 'BELUM', 'MINTA', 'WAIT', 'NEGO', 'DONE', 'CANCEL'].map((
                  status,
                ) {
                  final token = PermintaanHargaStatusHelper.getToken(status);
                  final desc = PermintaanHargaStatusHelper.getDescription(
                    status,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: token.base,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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

  Widget _buildPopoverTooltip() {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(79, 70, 229, 0.35),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Klik untuk melihat informasi status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismissTooltip,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -5,
            left: 12,
            child: CustomPaint(
              size: const Size(10, 6),
              painter: _TrianglePainter(color: const Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) =>
      '${d.day} ${_kShortMonths[d.month - 1]} ${d.year}';

  Future<void> _fetchList([String? query]) async {
    setState(() => _isLoading = true);

    final repo = ref.read(permintaanHargaRepositoryProvider);
    final results = await repo.getList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      status: _selectedStatus,
      search: query ?? _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _list = results;
        _isLoading = false;
      });
    }
  }

  bool _canEdit(PermintaanHargaItem item) {
    final status = item.status.trim().toUpperCase();
    const allowed = [
      'BELUM',
      'NEGO',
      'BELUM DIVERIFIKASI',
      'BELUM_DIVERIFIKASI',
      'DONE',
      'SELESAI',
    ];
    if (!allowed.contains(status)) return false;

    final user = ref.read(authProvider).user;
    if (user == null) return false;
    if (user.isManager) return true;

    if (item.userCreate.isNotEmpty &&
        item.userCreate.trim().toUpperCase() == user.nama.trim().toUpperCase()) {
      return true;
    }
    return true;
  }

  Future<void> _handleEdit(PermintaanHargaItem item) async {
    final repo = ref.read(permintaanHargaRepositoryProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      ),
    );

    final detail = await repo.getDetail(item.nomor);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (detail == null) {
      AppToast.error(context, 'Gagal memuat rincian permintaan harga');
      return;
    }

    final refresh = await context.push<bool>(
      '/permintaan-harga/edit',
      extra: detail,
    );

    if (refresh == true && mounted) {
      _fetchList();
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
      _fetchList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final useGrid = constraints.maxWidth >= 680;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.contentWidth(context)),
                child: Column(
                  children: [
                    // 1. TOP HEADER ALA UI-STYLING
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
                            onTap: () => context.pop(),
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
                                  'Permintaan Harga',
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
                            onTap: () => _fetchList(),
                            isLoading: _isLoading,
                            tooltip: 'Segarkan data',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. SEARCH & DATE RANGE CARD
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
                            // Search Box
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.06),
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
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Cari nomor, customer, atau barang...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (q) => _fetchList(q),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _searchController.clear();
                                        _fetchList();
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

                            // Date Range Selector Container (Sesuai Menu Lain)
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
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 8),
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
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_list.length} Data',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Tombol "Buat Permintaan Harga" (Sesuai React Native)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final refresh = await context.push<bool>(
                                  '/permintaan-harga/kalkulasi',
                                );
                                if (refresh == true) {
                                  _fetchList();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4F46E5),
                                      Color(0xFF06B6D4),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.28,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(79, 70, 229, 0.25),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Buat Permintaan Harga',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Status Chips with Popover Info Button
                            Row(
                              children: [
                                // Info Button & Popover Tooltip
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _showStatusLegendDialog,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFC7D2FE),
                                            width: 1.2,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                    if (_showTooltip)
                                      Positioned(
                                        bottom: 42,
                                        left: 0,
                                        child: _buildPopoverTooltip(),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _statusFilters.map((st) {
                                        final isSelected =
                                            _selectedStatus == st;
                                        final token =
                                            PermintaanHargaStatusHelper.getToken(
                                              st,
                                            );
                                        final baseColor = token.base;
                                        final unselectedBg = token.unselectedBg;
                                        final unselectedBorder =
                                            token.unselectedBorder;
                                        final unselectedText =
                                            token.unselectedText;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6.0,
                                          ),
                                          child: ChoiceChip(
                                            label: Row(
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
                                                  st == 'ALL'
                                                      ? 'Semua Status'
                                                      : st,
                                                ),
                                              ],
                                            ),
                                            selected: isSelected,
                                            selectedColor: baseColor,
                                            backgroundColor: unselectedBg,
                                            side: BorderSide(
                                              color: isSelected
                                                  ? baseColor
                                                  : unselectedBorder,
                                              width: 1.2,
                                            ),
                                            labelStyle: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : unselectedText,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                            onSelected: (val) {
                                              if (val) {
                                                setState(
                                                  () => _selectedStatus = st,
                                                );
                                                _fetchList();
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. DAFTAR PERMINTAAN HARGA
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : _list.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada data permintaan harga pada periode ini.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF4F46E5),
                              onRefresh: () => _fetchList(),
                              child: useGrid
                                  ? GridView.builder(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                        vertical: 6,
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: isDesktop ? 3 : 2,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: isDesktop
                                                ? 1.45
                                                : 1.32,
                                          ),
                                      itemCount: _list.length,
                                      itemBuilder: (context, index) {
                                        final item = _list[index];
                                        return _PermintaanHargaCard(
                                          item: item,
                                          currencyFormat: currencyFormat,
                                          onTap: () async {
                                            await context.push(
                                              '/permintaan-harga/${item.nomor}',
                                            );
                                            _fetchList();
                                          },
                                          onEdit: _canEdit(item)
                                              ? () => _handleEdit(item)
                                              : null,
                                        );
                                      },
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                        vertical: 6,
                                      ),
                                      itemCount: _list.length,
                                      separatorBuilder: (ctx, i) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final item = _list[index];
                                        return _PermintaanHargaCard(
                                          item: item,
                                          currencyFormat: currencyFormat,
                                          onTap: () async {
                                            await context.push(
                                              '/permintaan-harga/${item.nomor}',
                                            );
                                            _fetchList();
                                          },
                                          onEdit: _canEdit(item)
                                              ? () => _handleEdit(item)
                                              : null,
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
}

class _ParsedKetKalkulasi {
  final String? ppnStatus;
  final List<String> items;

  const _ParsedKetKalkulasi({this.ppnStatus, this.items = const []});
}

_ParsedKetKalkulasi _parseKetKalkulasi(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const _ParsedKetKalkulasi();
  }
  final rawParts = raw
      .split(RegExp(r'[;\n\r]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  String? ppnStatus;
  final items = <String>[];

  for (final part in rawParts) {
    final upper = part.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (upper == 'EXCPPN' ||
        upper == 'EXCLUDEPPN' ||
        upper == 'NONPPN' ||
        upper == 'EXCLUDE') {
      ppnStatus = 'EXCLUDE';
    } else if (upper == 'INCPPN' ||
        upper == 'INCLUDEPPN' ||
        upper == 'INCLUDE') {
      ppnStatus = 'INCLUDE';
    } else {
      items.add(part);
    }
  }

  return _ParsedKetKalkulasi(ppnStatus: ppnStatus, items: items);
}

class _KalkulasiRowItem extends StatelessWidget {
  final String status;
  final double hargaKalkulasi;
  final double mhHarga;
  final String ket;
  final NumberFormat currencyFormat;

  const _KalkulasiRowItem({
    required this.status,
    required this.hargaKalkulasi,
    required this.mhHarga,
    required this.ket,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final normStatus = status.toUpperCase().trim();
    final isDone = normStatus == 'DONE' || normStatus == 'SELESAI';
    final isNego = normStatus == 'NEGO';

    final hasCalc = hargaKalkulasi > 0;
    final hasMh = mhHarga > 0;

    if (!hasCalc && !hasMh && !isDone && !isNego) {
      return const SizedBox.shrink();
    }

    final parsed = _parseKetKalkulasi(ket);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: hasCalc && hasMh
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Kolom 1: Kalkulasi
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Kalkulasi: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            currencyFormat.format(hargaKalkulasi),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 12,
                        color: const Color(0xFFCBD5E1),
                      ),
                      // Kolom 2: Permintaan Harga
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Minta: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            currencyFormat.format(mhHarga),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isNego
                                  ? const Color(0xFF6B21A8)
                                  : (mhHarga > hargaKalkulasi
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasCalc ? 'Kalkulasi: ' : 'Minta: ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        currencyFormat.format(
                          hasCalc ? hargaKalkulasi : mhHarga,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: hasCalc
                              ? const Color(0xFF15803D)
                              : (isNego
                                    ? const Color(0xFF6B21A8)
                                    : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
          ),
          if (parsed.ppnStatus != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: parsed.ppnStatus == 'INCLUDE'
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: parsed.ppnStatus == 'INCLUDE'
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Text(
                parsed.ppnStatus == 'INCLUDE' ? 'Inc PPN' : 'Exc PPN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: parsed.ppnStatus == 'INCLUDE'
                      ? const Color(0xFF166534)
                      : const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermintaanHargaCard extends StatelessWidget {
  final PermintaanHargaItem item;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _PermintaanHargaCard({
    required this.item,
    required this.currencyFormat,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final token = PermintaanHargaStatusHelper.getToken(item.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.softCard,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header Row (Nomor di kiri, Status Badge di kanan)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.nomor,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: token.base.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: token.base, width: 1),
                      ),
                      child: Text(
                        item.status.isNotEmpty ? item.status : '-',
                        style: TextStyle(
                          color: token.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Nama Barang / Model
                if (item.nama.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.nama,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // 3. Customer dengan icon business
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.customer.isNotEmpty ? item.customer : '-',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // 4. Tanggal • Divisi
                const SizedBox(height: 2),
                Text(
                  '${_formatItemDate(item.tanggal)} • ${item.divisi.isNotEmpty ? item.divisi : '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // 5. Jumlah Order
                const SizedBox(height: 2),
                Text(
                  'Jumlah Order: ${item.jmlOrder.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),

                // 6. KalkulasiRowItem (Kalkulasi vs Minta + PPN mini badge)
                _KalkulasiRowItem(
                  status: item.status,
                  hargaKalkulasi: item.hargaKalkulasi,
                  mhHarga: item.harga,
                  ket: item.ketKalkulasi,
                  currencyFormat: currencyFormat,
                ),

                // 7. Footer: Tap info & Tombol Edit
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Tap untuk lihat detail',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    if (onEdit != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFC7D2FE),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: Color(0xFF4F46E5),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 11,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
