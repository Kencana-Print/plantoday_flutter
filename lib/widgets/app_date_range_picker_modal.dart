import 'package:flutter/material.dart';

const _kMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const _kShortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _kDayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

/// Fungsi pemanggil master modal rentang tanggal.
/// Adaptif: Menampilkan popup Card Dialog elegan di Desktop/Tablet,
/// dan Bottom Sheet ramah jempol di Mobile.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Pilih Rentang Tanggal',
}) async {
  final media = MediaQuery.of(context);
  final isDesktopOrTablet = media.size.width >= 600;

  if (isDesktopOrTablet) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.60),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _AppDateRangePickerCard(
            isDialog: true,
            initialStartDate: initialStartDate,
            initialEndDate: initialEndDate,
            firstDate: firstDate ?? DateTime(2020),
            lastDate: lastDate ?? DateTime(2030),
            title: title,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppDateRangePickerCard(
      isDialog: false,
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030),
      title: title,
    ),
  );
}

class _AppDateRangePickerCard extends StatefulWidget {
  final bool isDialog;
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _AppDateRangePickerCard({
    required this.isDialog,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_AppDateRangePickerCard> createState() => _AppDateRangePickerCardState();
}

class _AppDateRangePickerCardState extends State<_AppDateRangePickerCard> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _displayedMonth;

  // Mode pemilihan: 'start' = mengubah tanggal mulai, 'end' = mengubah tanggal selesai
  String _activeTarget = 'start';

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    _endDate = DateTime(
      widget.initialEndDate.year,
      widget.initialEndDate.month,
      widget.initialEndDate.day,
    );
    _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  String _formatDisplay(DateTime d) {
    return '${d.day} ${_kShortMonthNames[d.month - 1]} ${d.year}';
  }

  String _formatDayName(DateTime d) {
    const dayNames = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return dayNames[d.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int get _selectedDurationDays {
    return _endDate.difference(_startDate).inDays + 1;
  }

  String? _detectCurrentPreset() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_isSameDay(_startDate, today) && _isSameDay(_endDate, today)) {
      return 'today';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(_startDate, yesterday) && _isSameDay(_endDate, yesterday)) {
      return 'yesterday';
    }

    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    if (_isSameDay(_startDate, sevenDaysAgo) && _isSameDay(_endDate, today)) {
      return '7days';
    }

    final thirtyDaysAgo = today.subtract(const Duration(days: 29));
    if (_isSameDay(_startDate, thirtyDaysAgo) && _isSameDay(_endDate, today)) {
      return '30days';
    }

    final thisMonthStart = DateTime(today.year, today.month, 1);
    final thisMonthEnd = DateTime(today.year, today.month + 1, 0);
    if (_isSameDay(_startDate, thisMonthStart) &&
        _isSameDay(_endDate, thisMonthEnd)) {
      return 'thisMonth';
    }

    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0);
    if (_isSameDay(_startDate, lastMonthStart) &&
        _isSameDay(_endDate, lastMonthEnd)) {
      return 'lastMonth';
    }

    final thisYearStart = DateTime(today.year, 1, 1);
    final thisYearEnd = DateTime(today.year, 12, 31);
    if (_isSameDay(_startDate, thisYearStart) &&
        _isSameDay(_endDate, thisYearEnd)) {
      return 'thisYear';
    }

    return null;
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime s;
    DateTime e;

    switch (preset) {
      case 'today':
        s = DateTime(now.year, now.month, now.day);
        e = s;
        break;
      case 'yesterday':
        s = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        e = s;
        break;
      case '7days':
        e = DateTime(now.year, now.month, now.day);
        s = e.subtract(const Duration(days: 6));
        break;
      case '30days':
        e = DateTime(now.year, now.month, now.day);
        s = e.subtract(const Duration(days: 29));
        break;
      case 'thisMonth':
        s = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        e = DateTime(now.year, now.month, lastDay);
        break;
      case 'lastMonth':
        s = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0).day;
        e = DateTime(now.year, now.month - 1, lastDay);
        break;
      case 'thisYear':
        s = DateTime(now.year, 1, 1);
        e = DateTime(now.year, 12, 31);
        break;
      default:
        return;
    }

    setState(() {
      _startDate = s;
      _endDate = e;
      _displayedMonth = DateTime(s.year, s.month, 1);
      _activeTarget = 'start';
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      if (_activeTarget == 'start') {
        _startDate = day;
        if (_endDate.isBefore(day)) {
          _endDate = day;
        }
        _activeTarget = 'end';
      } else {
        if (day.isBefore(_startDate)) {
          _startDate = day;
          _activeTarget = 'end';
        } else {
          _endDate = day;
          _activeTarget = 'start';
        }
      }
    });
  }

  void _showYearPicker() async {
    final pickedYear = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Pilih Tahun',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 280,
          height: 300,
          child: YearPicker(
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            selectedDate: _displayedMonth,
            onChanged: (DateTime val) {
              Navigator.pop(ctx, val.year);
            },
          ),
        ),
      ),
    );

    if (pickedYear != null) {
      setState(() {
        _displayedMonth = DateTime(pickedYear, _displayedMonth.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset = _detectCurrentPreset();
    final durationDays = _selectedDurationDays;
    final now = DateTime.now();
    final isCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: widget.isDialog
            ? Border.all(color: const Color(0xFFE2E8F0))
            : null,
        boxShadow: widget.isDialog
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.16),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
                BoxShadow(
                  color: Color.fromRGBO(79, 70, 229, 0.08),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        widget.isDialog ? 18 : 12,
        20,
        20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator untuk bottom sheet di mobile
          if (!widget.isDialog)
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

          // Header Bar
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Pilih tanggal mulai dan tanggal selesai',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Tutup',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Quick Presets Row dengan indikator aktif
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  label: 'Hari Ini',
                  isActive: currentPreset == 'today',
                  onTap: () => _applyPreset('today'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Kemarin',
                  isActive: currentPreset == 'yesterday',
                  onTap: () => _applyPreset('yesterday'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: '7 Hari',
                  isActive: currentPreset == '7days',
                  onTap: () => _applyPreset('7days'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: '30 Hari',
                  isActive: currentPreset == '30days',
                  onTap: () => _applyPreset('30days'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Bulan Ini',
                  isActive: currentPreset == 'thisMonth',
                  onTap: () => _applyPreset('thisMonth'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Bulan Lalu',
                  isActive: currentPreset == 'lastMonth',
                  onTap: () => _applyPreset('lastMonth'),
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Tahun Ini',
                  isActive: currentPreset == 'thisYear',
                  onTap: () => _applyPreset('thisYear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Target Date Selector Cards (Mulai ➔ Selesai)
          Row(
            children: [
              // Kartu Tanggal Mulai
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _activeTarget = 'start'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _activeTarget == 'start'
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeTarget == 'start'
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFE2E8F0),
                        width: _activeTarget == 'start' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 13,
                              color: _activeTarget == 'start'
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tanggal Mulai',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _activeTarget == 'start'
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDisplay(_startDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _activeTarget == 'start'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _formatDayName(_startDate),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Indikator Durasi & Panah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '$durationDays Hari',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),

              // Kartu Tanggal Selesai
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _activeTarget = 'end'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _activeTarget == 'end'
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeTarget == 'end'
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFE2E8F0),
                        width: _activeTarget == 'end' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: _activeTarget == 'end'
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tanggal Selesai',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _activeTarget == 'end'
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDisplay(_endDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _activeTarget == 'end'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _formatDayName(_endDate),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Month Switcher Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: Color(0xFF1E293B),
                  ),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                        1,
                      );
                    });
                  },
                  tooltip: 'Bulan Sebelumnya',
                ),
                InkWell(
                  onTap: _showYearPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_kMonthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCurrentMonth)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _displayedMonth = DateTime(now.year, now.month, 1);
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bulan Ini',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: Color(0xFF1E293B),
                      ),
                      onPressed: () {
                        setState(() {
                          _displayedMonth = DateTime(
                            _displayedMonth.year,
                            _displayedMonth.month + 1,
                            1,
                          );
                        });
                      },
                      tooltip: 'Bulan Berikutnya',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Day Names Row (Min, Sen, Sel, ...)
          Row(
            children: _kDayNames.map((d) {
              final isSunday = d == 'Min';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSunday
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Calendar Grid (Simetris 7-Kolom per Minggu)
          _buildMonthCalendarGrid(),
          const SizedBox(height: 16),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        DateTimeRange(start: _startDate, end: _endDate),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: Text(
                      'Terapkan ($durationDays Hari)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
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

  Widget _buildPresetChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isActive ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendarGrid() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Minggu

    final List<Widget> weekRows = [];
    List<Widget> currentWeek = [];

    // Sel kosong sebelum tanggal 1
    for (int i = 0; i < startingWeekday; i++) {
      currentWeek.add(const Expanded(child: SizedBox(height: 38)));
    }

    final today = DateTime.now();

    for (int d = 1; d <= daysInMonth; d++) {
      final currentDay = DateTime(year, month, d);

      final isStart = _isSameDay(currentDay, _startDate);
      final isEnd = _isSameDay(currentDay, _endDate);
      final isInRange =
          currentDay.isAfter(_startDate) && currentDay.isBefore(_endDate);
      final isSameDaySelection = _isSameDay(_startDate, _endDate);
      final isToday = _isSameDay(currentDay, today);
      final isSunday = currentDay.weekday == DateTime.sunday;

      currentWeek.add(
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onDayTapped(currentDay),
            child: SizedBox(
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Continuous Range Connector Bar
                  if (!isSameDaySelection) ...[
                    if (isStart)
                      Positioned(
                        left: 18,
                        right: 0,
                        top: 2,
                        bottom: 2,
                        child: Container(color: const Color(0xFFEEF2FF)),
                      )
                    else if (isEnd)
                      Positioned(
                        left: 0,
                        right: 18,
                        top: 2,
                        bottom: 2,
                        child: Container(color: const Color(0xFFEEF2FF)),
                      )
                    else if (isInRange)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 2,
                        bottom: 2,
                        child: Container(color: const Color(0xFFEEF2FF)),
                      ),
                  ],

                  // Lingkaran / Box Tanggal
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (isStart || isEnd)
                          ? const Color(0xFF4F46E5)
                          : (isInRange
                              ? const Color(0xFFEEF2FF)
                              : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isToday && !isStart && !isEnd
                          ? Border.all(
                              color: const Color(0xFF4F46E5),
                              width: 1.5,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: (isStart || isEnd)
                            ? FontWeight.w900
                            : (isInRange || isToday
                                ? FontWeight.w800
                                : FontWeight.w600),
                        color: (isStart || isEnd)
                            ? Colors.white
                            : (isInRange
                                ? const Color(0xFF4338CA)
                                : (isSunday
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF0F172A))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Jika sudah 7 hari (minggu penuh), tambahkan ke weekRows dan buat baris baru
      if (currentWeek.length == 7) {
        weekRows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(children: currentWeek),
          ),
        );
        currentWeek = [];
      }
    }

    // Isi sisa kolom di minggu terakhir jika belum mencapai 7
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(const Expanded(child: SizedBox(height: 38)));
      }
      weekRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(children: currentWeek),
        ),
      );
    }

    return Column(children: weekRows);
  }
}
