import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/app_date_range_picker_modal.dart';
import '../../widgets/ui/app_card.dart';
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

class PenawaranListScreen extends ConsumerStatefulWidget {
  const PenawaranListScreen({super.key});

  @override
  ConsumerState<PenawaranListScreen> createState() =>
      _PenawaranListScreenState();
}

class _PenawaranListScreenState extends ConsumerState<PenawaranListScreen> {
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  List<PenawaranListItem> _penawaranList = [];
  bool _isLoading = false;
  String _selectedApproval = 'ALL'; // ALL, APPROVED, UNAPPROVED

  // State Sales (Khusus Manager)
  String _selectedSalesKode = '';
  String _selectedSalesName = 'Semua Sales';
  List<Map<String, String>> _salesList = [];

  @override
  void initState() {
    super.initState();
    _fetchPenawaran();
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

  Future<void> _loadSalesList() async {
    try {
      final repo = ref.read(penawaranRepositoryProvider);
      final rows = await repo.getMasterSales('');
      if (mounted) {
        setState(() {
          _salesList = rows;
        });
      }
    } catch (_) {}
  }

  String _formatYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) =>
      '${d.day} ${_kShortMonths[d.month - 1]} ${d.year}';

  Future<void> _fetchPenawaran([String? query]) async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(penawaranRepositoryProvider);
    final results = await repo.getPenawaranList(
      startDate: _formatYmd(_startDate),
      endDate: _formatYmd(_endDate),
      status: 'ALL',
      search: query ?? _searchController.text.trim(),
      salesKode: isManager && _selectedSalesKode.isNotEmpty
          ? _selectedSalesKode
          : null,
    );

    if (mounted) {
      setState(() {
        _penawaranList = results;
        _isLoading = false;
      });
    }
  }

  bool _canEdit(PenawaranListItem item) {
    if (item.isApproved) return false;
    if (item.approvalState.trim().toUpperCase() == 'WAIT') return false;

    final user = ref.read(authProvider).user;
    if (user == null) return false;
    if (user.isManager) return true;

    final authNama = user.nama.trim().toUpperCase();
    final rowSalesNama = item.sales.trim().toUpperCase();
    if (authNama.isNotEmpty && rowSalesNama.isNotEmpty) {
      return authNama == rowSalesNama ||
          authNama.contains(rowSalesNama) ||
          rowSalesNama.contains(authNama);
    }

    return true;
  }

  Future<void> _handleEdit(PenawaranListItem item) async {
    final repo = ref.read(penawaranRepositoryProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      ),
    );

    final detail = await repo.getPenawaranDetail(item.nomor);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (detail == null) {
      AppToast.error(context, 'Gagal memuat rincian penawaran');
      return;
    }

    final refresh = await context.push<bool>(
      '/penawaran/edit',
      extra: detail,
    );

    if (refresh == true && mounted) {
      _fetchPenawaran();
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
              final n = (s['nama'] ?? '').toLowerCase();
              final k = (s['kode'] ?? '').toLowerCase();
              return n.contains(searchKeyword.toLowerCase()) ||
                  k.contains(searchKeyword.toLowerCase());
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
                            selected: _selectedSalesKode.isEmpty,
                            trailing: _selectedSalesKode.isEmpty
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF4F46E5),
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedSalesKode = '';
                                _selectedSalesName = 'Semua Sales';
                              });
                              _fetchPenawaran();
                            },
                          ),
                          const Divider(height: 1),
                          ...filtered.map((s) {
                            final kode = s['kode'] ?? '';
                            final nama = s['nama'] ?? '';
                            final isSel = _selectedSalesKode == kode;
                            return ListTile(
                              leading: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF64748B),
                              ),
                              title: Text(
                                nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                kode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
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
                                  _selectedSalesKode = kode;
                                  _selectedSalesName = nama;
                                });
                                _fetchPenawaran();
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
      _fetchPenawaran();
    }
  }

  String _formatItemDate(String ymd) {
    if (ymd.isEmpty) return '-';
    try {
      final parts = ymd.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12) {
          return '$d ${_kShortMonths[m - 1]} $y';
        }
      }
      final dt = DateTime.parse(ymd);
      return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return ymd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    int approvedCount = 0;
    int unapprovedCount = 0;
    for (final item in _penawaranList) {
      if (item.isApproved) {
        approvedCount++;
      } else {
        unapprovedCount++;
      }
    }

    final filteredList = _penawaranList.where((p) {
      if (_selectedApproval == 'APPROVED') return p.isApproved;
      if (_selectedApproval == 'UNAPPROVED') return !p.isApproved;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);

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
                                  'Penawaran',
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
                            onTap: () => _fetchPenawaran(),
                            isLoading: _isLoading,
                            tooltip: 'Segarkan data',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. SEARCH & FILTER CARD
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
                            // Search Row (+ Filter Sales jika Manager)
                            Row(
                              children: [
                                Expanded(
                                  flex:
                                      ref.watch(authProvider).user?.isManager ==
                                          true
                                      ? 6
                                      : 10,
                                  child: Container(
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
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Cari nomor, customer, sales...',
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
                                            onSubmitted: (q) =>
                                                _fetchPenawaran(q),
                                          ),
                                        ),
                                        if (_searchController.text.isNotEmpty)
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              setState(() {
                                                _searchController.clear();
                                              });
                                              _fetchPenawaran('');
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
                                if (ref.watch(authProvider).user?.isManager ==
                                    true) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 5,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _showSalesPicker,
                                      child: Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedSalesKode.isNotEmpty
                                              ? const Color(0xFFEEF2FF)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _selectedSalesKode.isNotEmpty
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
                                                  _selectedSalesKode.isNotEmpty
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _selectedSalesName,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      _selectedSalesKode
                                                          .isNotEmpty
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
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Date Range Selector Container (Sesuai Standar PlanToday)
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
                                        border: Border.all(
                                          color: const Color(0xFFC7D2FE),
                                        ),
                                      ),
                                      child: Text(
                                        '${filteredList.length} Data',
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

                            // Filter Approval Chips (Seperti di React Native)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildApprovalTab(
                                    key: 'ALL',
                                    label: 'Semua (${_penawaranList.length})',
                                    icon: Icons.format_list_bulleted_rounded,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildApprovalTab(
                                    key: 'APPROVED',
                                    label: 'Sudah Diapprove ($approvedCount)',
                                    dotColor: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildApprovalTab(
                                    key: 'UNAPPROVED',
                                    label: 'Belum Diapprove ($unapprovedCount)',
                                    dotColor: const Color(0xFFF59E0B),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tombol Lebar Buat Penawaran
                            GestureDetector(
                              onTap: () async {
                                final refresh = await context.push<bool>(
                                  '/penawaran/create',
                                );
                                if (refresh == true) {
                                  _fetchPenawaran();
                                }
                              },
                              child: Container(
                                height: 44,
                                width: double.infinity,
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
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 8),
                                    Text(
                                      'Buat Penawaran Baru',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
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
                    const SizedBox(height: 12),

                    // 3. PENAWARAN (RESPONSIVE LIST / GRID)
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
                                'Tidak ada data penawaran pada periode ini.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF4F46E5),
                              onRefresh: () => _fetchPenawaran(),
                              child: constraints.maxWidth >= 640
                                  ? GridView.builder(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                        vertical: 6,
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: isDesktop ? 3 : 2,
                                            mainAxisExtent: 195,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 14,
                                          ),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredList[index];
                                        final canEdit = _canEdit(item);
                                        return _PenawaranCard(
                                          item: item,
                                          currencyFormat: currencyFormat,
                                          formattedDate: _formatItemDate(
                                            item.tanggal,
                                          ),
                                          onTap: () async {
                                            await context.push(
                                              '/penawaran/${Uri.encodeComponent(item.nomor)}',
                                              extra: item.nomor,
                                            );
                                            _fetchPenawaran();
                                          },
                                          onEdit: canEdit
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
                                      itemCount: filteredList.length,
                                      separatorBuilder: (ctx, i) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final item = filteredList[index];
                                        final canEdit = _canEdit(item);
                                        return _PenawaranCard(
                                          item: item,
                                          currencyFormat: currencyFormat,
                                          formattedDate: _formatItemDate(
                                            item.tanggal,
                                          ),
                                          onTap: () async {
                                            await context.push(
                                              '/penawaran/${Uri.encodeComponent(item.nomor)}',
                                              extra: item.nomor,
                                            );
                                            _fetchPenawaran();
                                          },
                                          onEdit: canEdit
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

  Widget _buildApprovalTab({
    required String key,
    required String label,
    IconData? icon,
    Color? dotColor,
  }) {
    final active = _selectedApproval == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedApproval = key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF4F46E5)
                : const Color.fromRGBO(15, 23, 42, 0.08),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
            ] else if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PenawaranCard extends StatelessWidget {
  final PenawaranListItem item;
  final NumberFormat currencyFormat;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _PenawaranCard({
    required this.item,
    required this.currencyFormat,
    required this.formattedDate,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = item.isApproved;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.nomor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: isApproved
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFED7AA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isApproved
                              ? Icons.verified_rounded
                              : Icons.schedule_rounded,
                          size: 11,
                          color: isApproved
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          isApproved ? 'Sudah Diapprove' : 'Belum Diapprove',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isApproved
                                ? const Color(0xFF059669)
                                : const Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.detailCount} item',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.customer.isNotEmpty ? item.customer : '-',
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
            '$formattedDate • ${item.perusahaan.isNotEmpty ? item.perusahaan : '-'}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            'Sales: ${item.sales.isNotEmpty ? item.sales : '-'}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormat.format(item.nominal),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4F46E5),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null) ...[
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
                    const SizedBox(width: 8),
                  ],
                  const Text(
                    'Lihat detail',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
