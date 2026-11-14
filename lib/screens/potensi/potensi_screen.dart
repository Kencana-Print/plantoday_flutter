import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/potensi_kandidat_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../repositories/potensi_repository.dart';
import '../../widgets/app_reload_button.dart';

class PotensiScreen extends ConsumerStatefulWidget {
  const PotensiScreen({super.key});

  @override
  ConsumerState<PotensiScreen> createState() => _PotensiScreenState();
}

class _PotensiScreenState extends ConsumerState<PotensiScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitting = false;

  List<PotensiKandidatItem> _rawKandidat = [];
  String _activeTab = 'ALL'; // 'ALL' | 'PENAWARAN' | 'MAP'
  String _selectedSales = '';
  List<String> _salesList = [];

  // Pilihan item batch
  final Map<String, PotensiKandidatItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _fetchKandidat();
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
          _salesList = rows
              .map((e) => e['nama'] ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchKandidat() async {
    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final isManager = user?.isManager ?? false;

    final repo = ref.read(potensiRepositoryProvider);
    final results = await repo.getPotensiKandidatList(
      sales: isManager && _selectedSales.isNotEmpty
          ? _selectedSales
          : (!isManager ? user?.nama : null),
    );

    if (mounted) {
      setState(() {
        _rawKandidat = results;
        if (_salesList.isEmpty && isManager) {
          final fromData =
              results
                  .map((e) => (e.salesNama ?? '').trim())
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

  String _formatDate(String? ymd) {
    if (ymd == null || ymd.isEmpty) return '-';
    try {
      final clean = ymd.split('T')[0].split(' ')[0];
      final parts = clean.split('-').map(int.parse).toList();
      const bulan = [
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
      return '${parts[2]} ${bulan[parts[1] - 1]} ${parts[0]}';
    } catch (_) {
      return ymd;
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
                              _fetchKandidat();
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
                              _fetchKandidat();
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

  Future<void> _submitBatch() async {
    if (_selectedItems.isEmpty) {
      AppToast.warning(
        context,
        'Pilih minimal 1 kandidat untuk dijadikan Potensi',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(potensiRepositoryProvider);
    final payloadList = _selectedItems.values
        .map((it) => it.toBatchPayload())
        .toList();

    final success = await repo.createPotensiBatch(payloadList);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        AppToast.success(
          context,
          'Berhasil menambahkan ${_selectedItems.length} potensi baru',
        );
        setState(() => _selectedItems.clear());
        _fetchKandidat();
      } else {
        AppToast.error(context, 'Gagal menyimpan potensi ke server');
      }
    }
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

    // Filter tab, sales, & search
    final q = _searchController.text.trim().toLowerCase();
    final filteredList = _rawKandidat.filter((it) {
      if (_activeTab == 'PENAWARAN' && it.tipeSumber != 'PENAWARAN') {
        return false;
      }
      if (_activeTab == 'MAP' && it.tipeSumber != 'MAP') {
        return false;
      }

      if (_selectedSales.isNotEmpty) {
        final sNama = (it.salesNama ?? '').toLowerCase();
        final sKode = (it.salesKode ?? '').toLowerCase();
        final target = _selectedSales.toLowerCase();
        if (sNama != target && sKode != target && !sNama.contains(target)) {
          return false;
        }
      }

      if (q.isNotEmpty) {
        final matchNomor = (it.penNomor ?? it.mspkNomor ?? '')
            .toLowerCase()
            .contains(q);
        final matchCustomer = (it.customerNama ?? '').toLowerCase().contains(q);
        final matchItem = it.namaItem.toLowerCase().contains(q);
        final matchSales = (it.salesNama ?? '').toLowerCase().contains(q);
        return matchNomor || matchCustomer || matchItem || matchSales;
      }

      return true;
    }).toList();

    final penawaranCount = _rawKandidat
        .where((it) => it.tipeSumber == 'PENAWARAN')
        .length;
    final mapCount = _rawKandidat.where((it) => it.tipeSumber == 'MAP').length;

    final selectedTotalNominal = _selectedItems.values.fold<double>(
      0.0,
      (acc, it) => acc + it.harga,
    );

    final isAllSelected =
        filteredList.isNotEmpty &&
        filteredList.every((it) => _selectedItems.containsKey(it.itemKey));

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
                                  'Potensi',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pilih kandidat Penawaran / MAP untuk dijadikan potensi',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Tombol Shortcut ke Laporan Potensi
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
                              onPressed: () => context.push('/laporan-potensi'),
                              icon: const Icon(
                                Icons.assessment_outlined,
                                size: 16,
                                color: Color(0xFF4F46E5),
                              ),
                              label: const Text(
                                'Laporan',
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
                            onTap: _fetchKandidat,
                            isLoading: _isLoading,
                            tooltip: 'Segarkan kandidat',
                            size: isDesktop ? 44 : 40,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. SEGMENTED TABS (SEMUA / PENAWARAN / MAP)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildTabPill(
                              label: 'Semua (${_rawKandidat.length})',
                              value: 'ALL',
                            ),
                            _buildTabPill(
                              label: 'Penawaran ($penawaranCount)',
                              value: 'PENAWARAN',
                            ),
                            _buildTabPill(
                              label: 'MAP ($mapCount)',
                              value: 'MAP',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. SEARCH & SALES FILTER ROW
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 23, 42, 0.02),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Cari nomor, customer, atau item...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12.5,
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
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isManager) ...[
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _showSalesPicker,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
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
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                      color: _selectedSales.isNotEmpty
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedSales.isNotEmpty
                                          ? _selectedSales
                                          : 'Sales: Semua',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedSales.isNotEmpty
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
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
                    ),
                    const SizedBox(height: 10),

                    // 4. BAR SELECT ALL
                    if (filteredList.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isAllSelected) {
                                    for (final it in filteredList) {
                                      _selectedItems.remove(it.itemKey);
                                    }
                                  } else {
                                    for (final it in filteredList) {
                                      _selectedItems[it.itemKey] = it;
                                    }
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isAllSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 20,
                                    color: isAllSelected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pilih Semua (${filteredList.length})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_selectedItems.length} item dipilih',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 5. GRID / LIST KANDIDAT
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
                                'Tidak ada kandidat potensi yang cocok.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : _buildAdaptiveGrid(
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              horizontalPadding: horizontalPadding,
                              items: filteredList,
                              currencyFormat: currencyFormat,
                            ),
                    ),

                    // 6. FLOATING BOTTOM BAR AKUMULASI (Muncul jika ada item dipilih)
                    if (_selectedItems.isNotEmpty)
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          14,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: Color.fromRGBO(15, 23, 42, 0.08),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.04),
                              blurRadius: 10,
                              offset: Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_selectedItems.length} Item Dipilih',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(selectedTotalNominal),
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.accent],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppShadows.button,
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _submitBatch,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Simpan Potensi (${_selectedItems.length})',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabPill({required String label, required String value}) {
    final isSelected = _activeTab == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _activeTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.06),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveGrid({
    required bool isDesktop,
    required bool isTablet,
    required double horizontalPadding,
    required List<PotensiKandidatItem> items,
    required NumberFormat currencyFormat,
  }) {
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    if (crossAxisCount == 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          6,
          horizontalPadding,
          24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _buildCardItem(item: items[index], currencyFormat: currencyFormat),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 175,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildCardItem(item: items[index], currencyFormat: currencyFormat),
    );
  }

  Widget _buildCardItem({
    required PotensiKandidatItem item,
    required NumberFormat currencyFormat,
  }) {
    final isSelected = _selectedItems.containsKey(item.itemKey);
    final isPenawaran = item.tipeSumber == 'PENAWARAN';

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItems.remove(item.itemKey);
          } else {
            _selectedItems[item.itemKey] = item;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color.fromRGBO(15, 23, 42, 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.03),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isPenawaran
                                  ? const Color(0xFFEEF2FF)
                                  : const Color(0xFFECFEFF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPenawaran
                                    ? const Color(0xFFC7D2FE)
                                    : const Color(0xFFA5F3FC),
                              ),
                            ),
                            child: Text(
                              item.tipeSumber,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isPenawaran
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF0891B2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.penNomor ?? item.mspkNomor ?? '-',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(item.tanggal),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.customerNama ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.namaItem,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.salesNama != null && item.salesNama!.isNotEmpty)
                        Text(
                          'Sales: ${item.salesNama}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        currencyFormat.format(item.harga),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T element) test) sync* {
    for (var element in this) {
      if (test(element)) yield element;
    }
  }
}
