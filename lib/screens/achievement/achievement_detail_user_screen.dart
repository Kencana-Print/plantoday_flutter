import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../repositories/achievement_repository.dart';
import 'circular_progress.dart';

class AchievementDetailUserScreen extends ConsumerStatefulWidget {
  final AchievementUserRow userRow;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;

  const AchievementDetailUserScreen({
    super.key,
    required this.userRow,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
  });

  @override
  ConsumerState<AchievementDetailUserScreen> createState() =>
      _AchievementDetailUserScreenState();
}

class _AchievementDetailUserScreenState
    extends ConsumerState<AchievementDetailUserScreen>
    with SingleTickerProviderStateMixin {
  List<AchievementMonthlyItem> _monthlyItems = [];
  bool _isLoading = false;
  late AnimationController _skeletonController;
  late Animation<double> _skeletonPulse;

  final List<String> _monthLabels = [
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

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _skeletonPulse = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );

    _fetchMonthlyDetail();
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthlyDetail() async {
    setState(() => _isLoading = true);

    final repo = ref.read(achievementRepositoryProvider);

    // Pastikan rentang data bulanan mencakup minimal 5 bulan sebelum toMonth & toYear
    // Contoh: jika difilter bulan Oktober (bulan 10), data Mei s/d Oktober (6 bulan) tetap dimuat
    final targetIndex = widget.toYear * 12 + (widget.toMonth - 1);
    final fiveMonthsPriorIndex = targetIndex - 5;
    final fromReqIndex = widget.fromYear * 12 + (widget.fromMonth - 1);
    final effectiveFromIndex = fromReqIndex < fiveMonthsPriorIndex ? fromReqIndex : fiveMonthsPriorIndex;
    final fetchFromYear = effectiveFromIndex ~/ 12;
    final fetchFromMonth = (effectiveFromIndex % 12) + 1;

    final fromYm =
        '$fetchFromYear-${fetchFromMonth.toString().padLeft(2, '0')}';
    final toYm =
        '${widget.toYear}-${widget.toMonth.toString().padLeft(2, '0')}';

    final items = await repo.getMonthlyOmsetByUser(
      kode: widget.userRow.kode,
      fromYm: fromYm,
      toYm: toYm,
    );

    if (mounted) {
      setState(() {
        _monthlyItems = items;
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(num n) {
    return 'Rp.${NumberFormat('#,###', 'id_ID').format(n)}';
  }

  String _formatDate(String? ymd) {
    if (ymd == null || ymd.isEmpty) return '-';
    final clean = ymd.trim();
    final dateOnly = clean.length >= 10 ? clean.substring(0, 10) : clean;
    final parts = dateOnly.split('-');
    if (parts.length != 3) return dateOnly;
    final y = parts[0];
    final m = parts[1];
    final d = parts[2];
    return '$d-$m-$y';
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel =
        '${_monthLabels[(widget.fromMonth - 1).clamp(0, 11)]} ${widget.fromYear}';
    final toLabel =
        '${_monthLabels[(widget.toMonth - 1).clamp(0, 11)]} ${widget.toYear}';
    final periodLabel = '$fromLabel — $toLabel';

    final u = widget.userRow;
    final target = u.target;
    final realisasi = u.realisasi;
    final isMissing = target <= 0 && realisasi <= 0;
    final selisih = realisasi - target;
    final isMet = realisasi >= target && target > 0;
    final ach = u.ach;

    // Kumpulkan seluruh data SPK dari semua bulan dan urutkan tanggal descending
    final allSpkList = _monthlyItems.expand((m) => m.detailSpk).toList();
    allSpkList.sort((a, b) {
      DateTime? dateA;
      DateTime? dateB;
      try {
        dateA = DateTime.tryParse(a.spkTanggal);
      } catch (_) {}
      try {
        dateB = DateTime.tryParse(b.spkTanggal);
      } catch (_) {}
      final timeA = dateA?.millisecondsSinceEpoch ?? 0;
      final timeB = dateB?.millisecondsSinceEpoch ?? 0;
      return timeB.compareTo(timeA);
    });

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF7F9FF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsiveContainer(
            maxWidth: ResponsiveHelper.contentWidth(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = ResponsiveHelper.isDesktop(context);
                final isTablet = ResponsiveHelper.isTablet(context);
                final horizontalPad = ResponsiveHelper.horizontalPadding(context);

                return Column(
                  children: [
                    // 1. TOP HEADER (Responsive)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        12,
                        horizontalPad,
                        10,
                      ),
                      child: Row(
                        children: [
                          // Tombol Back
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/achievement');
                              }
                            },
                            child: Container(
                              width: isDesktop ? 42 : 38,
                              height: isDesktop ? 42 : 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
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
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: isDesktop ? 20 : 18,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),

                          // Title & Subtitle di Tengah
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Detail Achievement',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 22 : 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${u.nama} • ${u.jabatan}',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Tombol Refresh di Kanan
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _fetchMonthlyDetail,
                            child: Container(
                              width: isDesktop ? 42 : 38,
                              height: isDesktop ? 42 : 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
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
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh_rounded,
                                      size: isDesktop ? 20 : 18,
                                      color: const Color(0xFF4F46E5),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isTablet || isDesktop) ...[
                      // 2. STAY DI ATAS: Card Chart Circle (Tablet & Desktop)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          6,
                          horizontalPad,
                          10,
                        ),
                        child: _buildTopPinnedSummaryCard(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          periodLabel: periodLabel,
                          target: target,
                          realisasi: realisasi,
                          selisih: selisih,
                          ach: ach,
                          isMet: isMet,
                          isMissing: isMissing,
                          allSpkList: allSpkList,
                        ),
                      ),

                      // FIELD PROGRESS REALISASI PER DIVISI (HISTORI 5 BULAN SEBELUMNYA + BULAN FILTER)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          0,
                          horizontalPad,
                          10,
                        ),
                        child: _buildDivisiProgressCard(allSpkList),
                      ),

                      // 3. SCROLLABLE DAFTAR SPK DI BAWAHNYA
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchMonthlyDetail,
                          color: const Color(0xFF4F46E5),
                          child: _buildTabletDesktopSpkList(
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                            horizontalPad: horizontalPad,
                            allSpkList: allSpkList,
                          ),
                        ),
                      ),
                    ] else ...[
                      // MOBILE: SCROLL TERPADU (SingleChildScrollView)
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchMonthlyDetail,
                          color: const Color(0xFF4F46E5),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPad,
                              6,
                              horizontalPad,
                              24,
                            ),
                            child: _buildMobileLayout(
                              periodLabel: periodLabel,
                              target: target,
                              realisasi: realisasi,
                              selisih: selisih,
                              ach: ach,
                              isMet: isMet,
                              isMissing: isMissing,
                              allSpkList: allSpkList,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── TOP PINNED SUMMARY CARD (Stay di Atas untuk Tablet & Desktop)
  Widget _buildTopPinnedSummaryCard({
    required bool isDesktop,
    required bool isTablet,
    required String periodLabel,
    required double target,
    required double realisasi,
    required double selisih,
    required double ach,
    required bool isMet,
    required bool isMissing,
    required List<AchievementDetailSpk> allSpkList,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.08),
        ),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sisi Kiri: Circular Progress Animated & Status Chip
          SizedBox(
            width: isDesktop ? 116 : 98,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMissing)
                  CircularProgressAnimated(
                    size: isDesktop ? 96 : 84,
                    strokeWidth: isDesktop ? 9.5 : 8.5,
                    progress: ach,
                    color: isMet
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF06B6D4),
                    textColor: const Color(0xFF0F172A),
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 22 : 18,
                    ),
                    child: const Text(
                      'No Data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _buildStatusChip(isMet: isMet),
              ],
            ),
          ),

          SizedBox(width: isDesktop ? 20 : 14),

          // Sisi Kanan: Periode & Metrik Angka
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        periodLabel,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _isLoading
                            ? 'Memuat...'
                            : '${allSpkList.length} Transaksi',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
                // 4 Metrik disusun dalam 2 kolom baris
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow('Target', _formatRupiah(target)),
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            'Realisasi',
                            _formatRupiah(realisasi),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isDesktop ? 24 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow(
                            'Selisih',
                            _formatRupiah(selisih),
                            valueColor: selisih < 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            'Total SPK',
                            _isLoading ? '...' : '${allSpkList.length} SPK',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DAFTAR SPK TABLET & DESKTOP (Scrollable Independen di Bawah Card Stay di Atas)
  Widget _buildTabletDesktopSpkList({
    required bool isDesktop,
    required bool isTablet,
    required double horizontalPad,
    required List<AchievementDetailSpk> allSpkList,
  }) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 24),
        child: _buildSkeletonList(isTablet: true),
      );
    }

    if (allSpkList.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color.fromRGBO(15, 23, 42, 0.08),
            ),
            boxShadow: AppShadows.softCard,
          ),
          child: _buildEmptyState(),
        ),
      );
    }

    final crossAxisCount = 2;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 24),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                ),
                boxShadow: AppShadows.softCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar SPK Terbit',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Text(
                        '${allSpkList.length} SPK',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allSpkList.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 118,
                    ),
                    itemBuilder: (context, idx) {
                      return _buildSpkCard(
                        allSpkList[idx],
                        marginZero: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (Summary Kompak di Atas, SPK di Bawah, Scroll Terpadu)
  Widget _buildMobileLayout({
    required String periodLabel,
    required double target,
    required double realisasi,
    required double selisih,
    required double ach,
    required bool isMet,
    required bool isMissing,
    required List<AchievementDetailSpk> allSpkList,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PROGRESS + RINGKASAN 2-KOLOM
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sisi Kiri: Chart & Status Chip
              SizedBox(
                width: 88,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMissing)
                      CircularProgressAnimated(
                        size: 84,
                        strokeWidth: 8.5,
                        progress: ach,
                        color: isMet
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF06B6D4),
                        textColor: const Color(0xFF0F172A),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No Data',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildStatusChip(isMet: isMet),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Sisi Kanan: Ringkasan Angka
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      height: 1,
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    _buildSummaryRow('Target', _formatRupiah(target)),
                    _buildSummaryRow('Realisasi', _formatRupiah(realisasi)),
                    _buildSummaryRow(
                      'Selisih',
                      _formatRupiah(selisih),
                      valueColor: selisih < 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                    ),
                    _buildSummaryRow(
                      'Total SPK',
                      _isLoading ? '...' : '${allSpkList.length} SPK',
                    ),
                  ],
                ),
              ),
            ],
          ),

          // DIVIDER LINE
          Container(
            height: 1,
            color: const Color.fromRGBO(15, 23, 42, 0.08),
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),

          // FIELD PROGRESS REALISASI PER DIVISI (HISTORI 5 BULAN SEBELUMNYA + BULAN FILTER)
          _buildDivisiProgressCard(allSpkList),

          const SizedBox(height: 14),

          // DAFTAR SPK SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar SPK',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
              if (allSpkList.isNotEmpty && !_isLoading)
                Text(
                  '${allSpkList.length} SPK',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            _buildSkeletonList()
          else if (allSpkList.isEmpty)
            _buildEmptyState()
          else
            Column(
              children: allSpkList.map((spk) {
                return _buildSpkCard(spk);
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── FIELD PROGRESS REALISASI PER DIVISI (HISTORI 5 BULAN SEBELUMNYA + BULAN FILTER)
  Widget _buildDivisiProgressCard(List<AchievementDetailSpk> spkList) {
    double realisasiSpanduk = 0.0;
    double realisasiGarmen = 0.0;
    double realisasiMmt = 0.0;

    for (final spk in spkList) {
      if (spk.spkDivisi == 1) {
        realisasiSpanduk += spk.nilai;
      } else if (spk.spkDivisi == 4) {
        realisasiGarmen += spk.nilai;
      } else if (spk.spkDivisi == 5) {
        realisasiMmt += spk.nilai;
      }
    }

    final totalSemua = realisasiSpanduk + realisasiGarmen + realisasiMmt;

    final pctSpanduk = totalSemua > 0 ? (realisasiSpanduk / totalSemua) * 100 : 0.0;
    final pctGarmen = totalSemua > 0 ? (realisasiGarmen / totalSemua) * 100 : 0.0;
    final pctMmt = totalSemua > 0 ? (realisasiMmt / totalSemua) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text(
                    'Realisasi per Divisi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '6 Bln Terakhir',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Divisi 1: Spanduk
          _buildDivisiProgressRow(
            label: '1 - Spanduk',
            color: const Color(0xFF4F46E5),
            nilai: realisasiSpanduk,
            percentage: pctSpanduk,
          ),
          const SizedBox(height: 10),

          // Divisi 4: Garmen
          _buildDivisiProgressRow(
            label: '4 - Garmen',
            color: const Color(0xFF8B5CF6),
            nilai: realisasiGarmen,
            percentage: pctGarmen,
          ),
          const SizedBox(height: 10),

          // Divisi 5: MMT
          _buildDivisiProgressRow(
            label: '5 - MMT',
            color: const Color(0xFF06B6D4),
            nilai: realisasiMmt,
            percentage: pctMmt,
          ),
        ],
      ),
    );
  }

  Widget _buildDivisiProgressRow({
    required String label,
    required Color color,
    required double nilai,
    required double percentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Text(
              '${_formatRupiah(nilai)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── CHIP STATUS TERCAPAI / BELUM
  Widget _buildStatusChip({required bool isMet}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 12,
            color: isMet ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            isMet ? 'TERCAPAI' : 'BELUM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isMet ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  // ── BARIS SUMMARY METRIK
  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── KARTU SPK
  Widget _buildSpkCard(AchievementDetailSpk spk, {bool marginZero = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: marginZero ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.08),
        ),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: No SPK + Badge Status di kiri, Tanggal di kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        spk.spkNomor,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (spk.spkClose)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A10B981),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Color(0xFF047857),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1AEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        child: const Text(
                          'OPEN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(spk.spkTanggal),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Nama SPK
          Text(
            spk.spkNama.isNotEmpty ? spk.spkNama : '-',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Nama Customer
          Text(
            spk.customerNama.isNotEmpty ? spk.customerNama : '-',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Footer: Meta (Harga • Order Pcs) di kiri, Total Nilai di kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '${_formatRupiah(spk.spkHarga)} • Order: ${spk.spkJumlah} Pcs',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatRupiah(spk.nilai),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SKELETON LIST
  Widget _buildSkeletonList({bool isTablet = false}) {
    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 118,
        ),
        itemBuilder: (context, idx) =>
            _SpkSkeletonCard(pulse: _skeletonPulse, marginZero: true),
      );
    }
    return Column(
      children: [
        _SpkSkeletonCard(pulse: _skeletonPulse),
        _SpkSkeletonCard(pulse: _skeletonPulse),
        _SpkSkeletonCard(pulse: _skeletonPulse),
      ],
    );
  }

  // ── EMPTY STATE
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(241, 245, 249, 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromRGBO(15, 23, 42, 0.08),
        ),
      ),
      child: const Text(
        'Tidak ada SPK terbit di periode ini',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SpkSkeletonCard extends StatelessWidget {
  final Animation<double> pulse;
  final bool marginZero;

  const _SpkSkeletonCard({
    required this.pulse,
    this.marginZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Opacity(
          opacity: pulse.value,
          child: Container(
            margin: EdgeInsets.only(bottom: marginZero ? 0 : 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color.fromRGBO(15, 23, 42, 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBar(width: 90, height: 14),
                    _skeletonBar(width: 70, height: 12),
                  ],
                ),
                const SizedBox(height: 6),
                _skeletonBar(width: 170, height: 13),
                const SizedBox(height: 6),
                _skeletonBar(width: 120, height: 12),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBar(width: 110, height: 12),
                    _skeletonBar(width: 60, height: 12),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(148, 163, 184, 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
