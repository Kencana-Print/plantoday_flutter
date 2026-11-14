import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/achievement_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/achievement_repository.dart';
import '../../widgets/ui/app_card.dart';
import 'circular_progress.dart';
import '../../widgets/app_reload_button.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

const _kFullMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

class AchievementScreen extends ConsumerStatefulWidget {
  const AchievementScreen({super.key});

  @override
  ConsumerState<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends ConsumerState<AchievementScreen> {
  final _searchController = TextEditingController();

  late int _fromYear;
  late int _fromMonth;
  late int _toYear;
  late int _toMonth;

  List<AchievementUserRow> _rows = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromYear = now.year;
    _fromMonth = now.month;
    _toYear = now.year;
    _toMonth = now.month;
    _fetchAchievement();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAchievement() async {
    setState(() => _isLoading = true);

    final repo = ref.read(achievementRepositoryProvider);
    final results = await repo.getOmsetRange(
      fromYear: _fromYear,
      fromMonth: _fromMonth,
      toYear: _toYear,
      toMonth: _toMonth,
    );

    if (mounted) {
      setState(() {
        _rows = results;
        _isLoading = false;
      });
    }
  }

  String _formatRupiahShort(double n) {
    if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(1)}T';
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}M';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}Jt';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}Rb';
    return n.round().toString();
  }

  String _formatRupiahFull(double n) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp.',
      decimalDigits: 0,
    );
    return f.format(n);
  }

  String _formatMonthYear(int month, int year) {
    final idx = (month - 1).clamp(0, 11);
    return '${_kShortMonths[idx]} $year';
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
    });

    _fetchAchievement();
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
                              _kFullMonthNames[i],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
    final isManager = user?.isManager ?? false;

    // Filter Rows sesuai Manager vs Sales
    final filteredRows = _rows.where((r) {
      if (!isManager) {
        final myName = (user?.nama ?? '').trim().toLowerCase();
        final myKode =
            (user?.kode ?? user?.salesKode ?? '').trim().toLowerCase();
        final matches = (myKode.isNotEmpty && r.kode.toLowerCase() == myKode) ||
            (myName.isNotEmpty && r.nama.toLowerCase().contains(myName));
        final hasAnyMatch = _rows.any((x) =>
            (myKode.isNotEmpty && x.kode.toLowerCase() == myKode) ||
            (myName.isNotEmpty && x.nama.toLowerCase().contains(myName)));
        return hasAnyMatch ? matches : true;
      }

      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return r.nama.toLowerCase().contains(q) ||
          r.jabatan.toLowerCase().contains(q);
    }).toList();

    // Akumulasi Target & Realisasi
    final totalTarget =
        filteredRows.fold<double>(0.0, (acc, r) => acc + r.target);
    final totalRealisasi =
        filteredRows.fold<double>(0.0, (acc, r) => acc + r.realisasi);
    final totalAchPct =
        totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : 0.0;
    final isMet = totalRealisasi >= totalTarget && totalTarget > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: ResponsiveHelper.contentWidth(context),
          child: Column(
            children: [
              // 1. TOP HEADER ALA REACT-NATIVE
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                            'Achievement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isManager
                                ? 'Rekap Achievement Seluruh Sales'
                                : 'Rekap Achievement Pribadi',
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
                      onTap: _fetchAchievement,
                      isLoading: _isLoading,
                      tooltip: 'Segarkan data',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. RINGKASAN PROGRESS DENGAN CIRCULAR PROGRESS (ALA REACT NATIVE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.08),
                    ),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Row(
                    children: [
                      // Sisi Kiri: Circular Progress Animated
                      CircularProgressAnimated(
                        size: 78,
                        strokeWidth: 8,
                        progress: totalAchPct,
                        color: isMet
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF06B6D4),
                        bgColor: const Color.fromRGBO(15, 23, 42, 0.08),
                        textColor: const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 16),

                      // Sisi Kanan: Informasi & Statistik Ringkas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Progress Pencapaian',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMet
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isMet
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isMet
                                            ? Icons.check_circle_rounded
                                            : Icons.schedule_rounded,
                                        size: 11,
                                        color: isMet
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isMet ? 'TERCAPAI' : 'BELUM',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: isMet
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Target
                            Row(
                              children: [
                                const SizedBox(
                                  width: 60,
                                  child: Text(
                                    'Target',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const Text(
                                  ': ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _formatRupiahFull(totalTarget),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),

                            // Realisasi
                            Row(
                              children: [
                                const SizedBox(
                                  width: 60,
                                  child: Text(
                                    'Realisasi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const Text(
                                  ': ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _formatRupiahFull(totalRealisasi),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: isMet
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF4F46E5),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // User Tim (Khusus Manager)
                            if (isManager) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 60,
                                    child: Text(
                                      'User',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    ': ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${filteredRows.length} Orang',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. RENTANG PERIODE AWAL & PERIODE AKHIR RAMPING (ALA REACT NATIVE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
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
                            onTap: () => _showMonthYearPicker(isStart: true),
                            child: Container(
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatMonthYear(_fromMonth, _fromYear),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: Color(0xFF0F172A),
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
                            onTap: () => _showMonthYearPicker(isStart: false),
                            child: Container(
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatMonthYear(_toMonth, _toYear),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: Color(0xFF0F172A),
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
              ),
              const SizedBox(height: 12),

              // 4. PENCARIAN (KHUSUS MANAGER)
              if (isManager) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Cari nama / jabatan...',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
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
                ),
                const SizedBox(height: 12),
              ],

              // 5. DAFTAR ACHIEVEMENT TIAP SALES (CARD SAMA DENGAN REACT NATIVE)
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    : filteredRows.isEmpty
                        ? Center(
                            child: Text(
                              _rows.isEmpty
                                  ? 'Data tidak ditemukan'
                                  : 'Tidak ada sales yang cocok dengan pencarian.',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF4F46E5),
                            onRefresh: _fetchAchievement,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 640;
                                if (isWide) {
                                  return GridView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 84,
                                    ),
                                    itemCount: filteredRows.length,
                                    itemBuilder: (context, index) {
                                      final row = filteredRows[index];
                                      final prog = (row.target > 0)
                                          ? ((row.realisasi / row.target) * 100)
                                              .clamp(0.0, 500.0)
                                          : 0.0;
                                      final achValue =
                                          row.ach > 0 ? row.ach : prog;
                                      final barFill =
                                          (achValue / 100.0).clamp(0.0, 1.0);

                                      return _AchievementUserCardRN(
                                        row: row,
                                        achValue: achValue,
                                        barFill: barFill,
                                        targetShort:
                                            _formatRupiahShort(row.target),
                                        realisasiShort:
                                            _formatRupiahShort(row.realisasi),
                                        onTap: () {
                                          context.push('/achievement/detail',
                                              extra: {
                                                'userRow': row,
                                                'fromYear': _fromYear,
                                                'fromMonth': _fromMonth,
                                                'toYear': _toYear,
                                                'toMonth': _toMonth,
                                              });
                                        },
                                      );
                                    },
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  itemCount: filteredRows.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final row = filteredRows[index];
                                    final prog = (row.target > 0)
                                        ? ((row.realisasi / row.target) * 100)
                                            .clamp(0.0, 500.0)
                                        : 0.0;
                                    final achValue =
                                        row.ach > 0 ? row.ach : prog;
                                    final barFill =
                                        (achValue / 100.0).clamp(0.0, 1.0);

                                    return _AchievementUserCardRN(
                                      row: row,
                                      achValue: achValue,
                                      barFill: barFill,
                                      targetShort:
                                          _formatRupiahShort(row.target),
                                      realisasiShort:
                                          _formatRupiahShort(row.realisasi),
                                      onTap: () {
                                        context.push('/achievement/detail',
                                            extra: {
                                              'userRow': row,
                                              'fromYear': _fromYear,
                                              'fromMonth': _fromMonth,
                                              'toYear': _toYear,
                                              'toMonth': _toMonth,
                                            });
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementUserCardRN extends StatelessWidget {
  final AchievementUserRow row;
  final double achValue;
  final double barFill;
  final String targetShort;
  final String realisasiShort;
  final VoidCallback onTap;

  const _AchievementUserCardRN({
    required this.row,
    required this.achValue,
    required this.barFill,
    required this.targetShort,
    required this.realisasiShort,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMet = achValue >= 100;
    final isMid = achValue > 0 && !isMet;

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;

    if (isMet) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF16A34A);
    } else if (isMid) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFFDE68A);
      badgeText = const Color(0xFFD97706);
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeBorder = const Color(0xFFE2E8F0);
      badgeText = const Color(0xFF64748B);
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama User • Jabatan
                Text(
                  '${row.nama} • ${row.jabatan}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),

                // Target & Realisasi Singkat (Nominal diselaraskan w900)
                Text.rich(
                  TextSpan(
                    text: 'Target: ',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: '$targetShort  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const TextSpan(text: '•  Realisasi: '),
                      TextSpan(
                        text: realisasiShort,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isMet
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Bar Fill Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 5,
                    width: double.infinity,
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: barFill,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMet
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Persentase Badge di Sebelah Kanan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              '${achValue.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: badgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
