import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/invoice_jatuh_tempo_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/invoice_jatuh_tempo_repository.dart';
import '../../widgets/app_reload_button.dart';

class InvoiceJatuhTempoScreen extends ConsumerStatefulWidget {
  const InvoiceJatuhTempoScreen({super.key});

  @override
  ConsumerState<InvoiceJatuhTempoScreen> createState() =>
      _InvoiceJatuhTempoScreenState();
}

class _InvoiceJatuhTempoScreenState
    extends ConsumerState<InvoiceJatuhTempoScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = false;
  InvoiceJatuhTempoSummary? _summary;
  List<InvoiceJatuhTempoItem> _items = [];

  String _selectedSales = '';
  List<String> _cachedSalesList = [];
  final Set<String> _expandedSales = <String>{};
  final Map<String, int> _itemsLimitPerSales = <String, int>{};

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

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

  List<String> get _salesList {
    if (_cachedSalesList.isNotEmpty) return _cachedSalesList;
    final fromSummary = _summary?.availableSalesNames ?? const [];
    if (fromSummary.isNotEmpty) {
      _cachedSalesList = fromSummary;
      return _cachedSalesList;
    }
    final set = <String>{};
    for (final it in _items) {
      final name = it.salNama.trim();
      if (name.isNotEmpty && name != '(Tanpa Sales)') {
        set.add(name);
      }
    }
    final list = set.toList()..sort();
    if (list.isNotEmpty) _cachedSalesList = list;
    return list;
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(invoiceJatuhTempoRepositoryProvider);
    final result = await repo.getInvoiceJatuhTempo(
      sales: _selectedSales.isNotEmpty ? _selectedSales : null,
    );

    if (mounted) {
      setState(() {
        _summary = result.summary;
        _items = result.items;
        _isLoading = false;

        if (_selectedSales.isEmpty) {
          final names = result.summary?.availableSalesNames ?? const [];
          if (names.isNotEmpty) {
            _cachedSalesList = names;
          }
        }

        // Otomatis buka grup pertama jika belum ada yang dibuka
        if (_expandedSales.isEmpty && _items.isNotEmpty) {
          final firstSales = _items.first.salNama.trim().isNotEmpty
              ? _items.first.salNama.trim()
              : '(Tanpa Sales)';
          _expandedSales.add(firstSales);
        }
      });
    }
  }

  List<InvoiceJatuhTempoItem> get _filteredItems {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((it) {
      return it.nota.toLowerCase().contains(q) ||
          it.notaTampil.toLowerCase().contains(q) ||
          it.cusNama.toLowerCase().contains(q) ||
          it.cusKode.toLowerCase().contains(q) ||
          it.salNama.toLowerCase().contains(q);
    }).toList();
  }

  Color _agingColor(int hari) {
    if (hari > 90) return const Color(0xFFEA580C);
    if (hari > 60) return const Color(0xFFF97316);
    if (hari > 30) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  Color _agingBg(int hari) {
    if (hari > 90) return const Color(0xFFFFEDD5);
    if (hari > 60) return const Color(0xFFFFEDD5);
    if (hari > 30) return const Color(0xFFFEF3C7);
    return const Color(0xFFDCFCE7);
  }

  void _showSalesPicker() {
    String q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _salesList
                .where((s) => s.toLowerCase().contains(q.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Sales',
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
                              child: const Text('Reset'),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setModalState(() => q = v),
                        decoration: InputDecoration(
                          hintText: 'Cari nama sales...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, idx) {
                          final sName = filtered[idx];
                          final isSelected = _selectedSales == sName;
                          return ListTile(
                            title: Text(
                              sName,
                              style: TextStyle(
                                fontSize: 14,
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
    final displayList = _filteredItems;
    final isSearching = _searchController.text.trim().isNotEmpty;
    final salesGroups = InkasoSalesGroup.groupItems(
      displayList,
      summaryBySales: isSearching ? null : _summary?.bySales,
    );

    final totalInvoiceAktif = displayList.length;
    final totalSisa = displayList.fold<double>(0.0, (acc, it) => acc + it.sisa);
    final groupsRealisasi = salesGroups.fold<double>(
      0.0,
      (acc, g) => acc + g.totalTerealisasi,
    );
    final totalTerealisasi =
        !isSearching && (_summary?.totalRealisasi ?? 0) > groupsRealisasi
        ? _summary!.totalRealisasi
        : groupsRealisasi;
    final totalBatal = (_selectedSales.isEmpty && !isSearching)
        ? (_summary?.totalBatal ?? 0.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final horizontalPadding =
                ResponsiveHelper.horizontalPadding(context);
            final maxContainerWidth = ResponsiveHelper.contentWidth(context);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContainerWidth),
                child: Column(
                  children: [
                    // 1. TOP HEADER
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
                                context.go('/');
                              }
                            },
                            child: Container(
                              width: isDesktop ? 44 : 42,
                              height: isDesktop ? 44 : 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      const Color.fromRGBO(15, 23, 42, 0.08),
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
                              children: [
                                const Text(
                                  'Invoice Jatuh Tempo',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalInvoiceAktif invoice aktif · ${salesGroups.length} sales',
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
                    const SizedBox(height: 12),

                    // 2. KPI SUMMARY BAR (4 Metrik Manksi: Invoice Aktif, Sisa Tagihan, Terealisasi, Batal)
                    if (!_isLoading)
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
                            boxShadow: AppShadows.card,
                          ),
                          child: Row(
                            children: [
                              _buildKpiStat(
                                label: 'Invoice Aktif',
                                value: '$totalInvoiceAktif',
                                subValue: '${salesGroups.length} Sales',
                                valueColor: const Color(0xFF4F46E5),
                              ),
                              _buildVerticalDivider(),
                              _buildKpiStat(
                                label: 'Sisa Tagihan',
                                value: FormatHelper.shortNum(totalSisa),
                                subValue: _currencyFormat.format(totalSisa),
                                valueColor: const Color(0xFFEA580C),
                              ),
                              _buildVerticalDivider(),
                              _buildKpiStat(
                                label: 'Terealisasi',
                                value: FormatHelper.shortNum(totalTerealisasi),
                                subValue: _currencyFormat.format(
                                  totalTerealisasi,
                                ),
                                valueColor: const Color(0xFF10B981),
                              ),
                              _buildVerticalDivider(),
                              _buildKpiStat(
                                label: 'Batal',
                                value: FormatHelper.shortNum(totalBatal),
                                subValue: _currencyFormat.format(totalBatal),
                                valueColor: const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // 3. SEARCH & FILTER SALES
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: AppShadows.softCard,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        const Color.fromRGBO(15, 23, 42, 0.06),
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
                                              'Cari nota / customer / sales...',
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
                                        onSubmitted: (_) => setState(() {}),
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
                            if (isManager && _salesList.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showSalesPicker,
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedSales.isNotEmpty
                                        ? const Color(0xFFFFEDD5)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedSales.isNotEmpty
                                          ? const Color(0xFFEA580C)
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
                                            ? const Color(0xFFEA580C)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedSales.isNotEmpty
                                            ? _selectedSales.split(' ').first
                                            : 'Semua Sales',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedSales.isNotEmpty
                                              ? const Color(0xFFEA580C)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. LIST PER SALES (ACCORDION) & DETAIL INKASO
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFEA580C),
                              ),
                            )
                          : salesGroups.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Tidak ada invoice jatuh tempo.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  color: const Color(0xFFEA580C),
                                  onRefresh: () => _fetchData(),
                                  child: ListView.separated(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      4,
                                      horizontalPadding,
                                      20,
                                    ),
                                    itemCount: salesGroups.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, idx) {
                                      final grp = salesGroups[idx];
                                      final isExpanded = _expandedSales
                                          .contains(grp.salNama);
                                      return _buildSalesAccordionCard(
                                        grp,
                                        isExpanded,
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

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildKpiStat({
    required String label,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subValue,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAccordionCard(InkasoSalesGroup grp, bool isExpanded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFFEA580C).withValues(alpha: 0.35)
              : const Color.fromRGBO(15, 23, 42, 0.08),
          width: isExpanded ? 1.3 : 1.0,
        ),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Sales (Mirip v-expansion-panel-title di Manksi)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSales.remove(grp.salNama);
                } else {
                  _expandedSales.add(grp.salNama);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          grp.salNama.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${grp.jmlInvoice} invoice',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'Sisa ${FormatHelper.shortNum(grp.totalSisa)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        if (grp.totalTerealisasi > 0)
                          Text(
                            'Terealisasi ${FormatHelper.shortNum(grp.totalTerealisasi)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Detail Inkaso milik Sales ini
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Builder(builder: (context) {
              final limit = _itemsLimitPerSales[grp.salNama] ?? 50;
              final displayItems = grp.items.take(limit).toList();
              final hasMore = grp.items.length > limit;

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ...displayItems.map((item) {
                      final color = _agingColor(item.terlambatHari);
                      final bg = _agingBg(item.terlambatHari);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  item.notaTampil.isNotEmpty
                                      ? item.notaTampil
                                      : item.nota,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  '${item.tempo} · ${item.terlambatHari}h',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.cusNama.isNotEmpty
                                ? item.cusNama
                                : item.cusKode,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _miniMetric(
                                  'Nominal Awal',
                                  _currencyFormat.format(item.nominal),
                                ),
                              ),
                              Expanded(
                                child: _miniMetric(
                                  'Terealisasi',
                                  _currencyFormat.format(item.terbayar),
                                  valueColor: const Color(0xFF10B981),
                                ),
                              ),
                              Expanded(
                                child: _miniMetric(
                                  'Sisa Tagihan',
                                  _currencyFormat.format(item.sisa),
                                  valueColor: const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                          if (item.tglTarget.isNotEmpty ||
                              item.catatan.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (item.tglTarget.isNotEmpty)
                                  Text(
                                    'Target Bayar: ${item.tglTarget}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                if (item.catatan.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      '${item.catatan}${item.userCreate.isNotEmpty ? ' · ${item.userCreate}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                    }),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _itemsLimitPerSales[grp.salNama] = limit + 50;
                            });
                          },
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(
                            'Tampilkan 50 invoice lagi (${grp.items.length - limit} tersisa)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
