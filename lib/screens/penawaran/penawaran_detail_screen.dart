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
import '../../services/penawaran_pdf_service.dart';

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

class PenawaranDetailScreen extends ConsumerStatefulWidget {
  final String nomor;

  const PenawaranDetailScreen({super.key, required this.nomor});

  @override
  ConsumerState<PenawaranDetailScreen> createState() =>
      _PenawaranDetailScreenState();
}

class _PenawaranDetailScreenState extends ConsumerState<PenawaranDetailScreen> {
  PenawaranHeader? _header;
  List<PenawaranDetailItem> _details = [];
  List<PenawaranActivityLog> _activityLogs = [];
  bool _isLoading = true;
  bool _isExportingPdf = false;
  bool _isSubmittingApproval = false;

  String get _decodedNomor => Uri.decodeComponent(widget.nomor);

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final repo = ref.read(penawaranRepositoryProvider);

    try {
      final results = await Future.wait([
        repo.getPenawaranDetail(_decodedNomor),
        repo.getPenawaranActivityLogs(_decodedNomor),
      ]);

      if (mounted) {
        final detailData = results[0] as PenawaranDetailData?;
        final logsData = results[1] as List<PenawaranActivityLog>?;

        setState(() {
          _header = detailData?.header;
          _details = detailData?.details ?? [];
          _activityLogs = logsData ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDisplayDate(String ymd) {
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

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$dd/$mm/$yyyy $hh:$mi:$ss';
    } catch (_) {
      return raw;
    }
  }

  void _showUnapprovedModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicator bar
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(79, 70, 229, 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              // Icon Lock Clock
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_clock_rounded,
                  size: 32,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Penawaran Belum Diapprove',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                'Dokumen penawaran ini belum ditandatangani atau belum diapprove oleh manager, sehingga belum dapat dieksport ke PDF.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestChangeDialog() {
    final isSigned = _header?.isApproved ?? false;
    if (isSigned) {
      AppToast.warning(
        context,
        'Penawaran sudah diapprove dan tidak dapat diajukan perubahan',
      );
      return;
    }

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pengajuan Perubahan',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajukan perubahan data penawaran $_decodedNomor ke manager?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Jelaskan alasan perubahan data...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pengajuan akan dikirim untuk persetujuan manager',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final alasan = reasonController.text.trim();
              if (alasan.isEmpty) {
                AppToast.error(context, 'Alasan pengajuan wajib diisi');
                return;
              }
              Navigator.pop(ctx);
              final repo = ref.read(penawaranRepositoryProvider);
              final success = await repo.requestApprovalPerubahan(
                _decodedNomor,
                alasan: alasan,
              );

              if (mounted) {
                if (success) {
                  AppToast.success(
                    context,
                    'Pengajuan perubahan berhasil dibuat',
                  );
                  _fetchDetail();
                } else {
                  AppToast.error(context, 'Gagal mengajukan perubahan');
                }
              }
            },
            child: const Text(
              'Ajukan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Approval',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setujui dan tandatangani penawaran $_decodedNomor secara digital?',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Catatan approval (opsional)',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSubmittingApproval = true);
              final repo = ref.read(penawaranRepositoryProvider);
              final success = await repo.approvePenawaran(
                _decodedNomor,
                note: noteController.text.trim(),
              );

              if (mounted) {
                setState(() => _isSubmittingApproval = false);
                if (success) {
                  AppToast.success(context, 'Penawaran berhasil disetujui');
                  _fetchDetail();
                } else {
                  AppToast.error(context, 'Gagal menyetujui penawaran');
                }
              }
            },
            child: const Text(
              'Ya, Approve',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportPdf() async {
    final header = _header;
    if (header == null) return;

    final isSigned = header.isApproved;

    // Logika React Native: Jika belum signed, tampilkan dialog penjelasan
    if (!isSigned) {
      _showUnapprovedModal();
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await PenawaranPdfService.exportPenawaran(
        header: header,
        details: _details,
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal mengekspor PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final header = _header;
    final isSigned = header?.isApproved ?? false;
    final canEdit =
        header != null && !isSigned && header.approvalState.trim().toUpperCase() != 'WAIT';

    final user = ref.watch(authProvider).user;
    final isManager = user?.isManager ?? false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F9FF), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ResponsiveContainer(
            maxWidth: ResponsiveHelper.formWidth(context),
            child: Column(
              children: [
                // 1. HEADER AREA (Persis styles.headerArea React Native)
                Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Detail Penawaran',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _decodedNomor,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final refresh = await context.push<bool>(
                            '/penawaran/edit',
                            extra: PenawaranDetailData(
                              header: header,
                              details: _details,
                            ),
                          );
                          if (refresh == true) {
                            _fetchDetail();
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      )
                    else
                      const SizedBox(
                        width: 38,
                      ),
                  ],
                ),
              ),

              // 2. KONTEN DETAIL (Persis FlatList React Native)
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF4F46E5)),
                            SizedBox(height: 10),
                            Text(
                              'Memuat detail penawaran...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : header == null
                    ? const Center(
                        child: Text(
                          'Data tidak ditemukan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchDetail,
                        color: const Color(0xFF4F46E5),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            2,
                            20,
                            (isManager ? 85 : 145) +
                                MediaQuery.of(context).padding.bottom,
                          ),
                          children: [
                            // KARTU 1: Informasi Header (styles.sectionCard)
                            _buildHeaderSectionCard(header, currencyFormat),
                            const SizedBox(height: 10),

                            // LIST ITEM-ITEM RINCIAN BARANG (styles.itemCard)
                            ..._details.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return _buildDetailItemCard(
                                item: item,
                                index: index,
                                currencyFormat: currencyFormat,
                              );
                            }),

                            // KARTU 2: Activity Log jika ada (styles.sectionCard)
                            if (_activityLogs.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildActivityLogSectionCard(_activityLogs),
                            ],
                          ],
                        ),
                      ),
              ),

              // 3. BOTTOM ACTION (Persis styles.bottomAction React Native)
              if (!_isLoading && header != null)
                _buildBottomAction(isManager: isManager, isSigned: isSigned),
            ],
          ),
        ),
      ),
    ),
  );
  }

  // --- WIDGET KARTU 1: INFORMASI HEADER ---
  Widget _buildHeaderSectionCard(
    PenawaranHeader header,
    NumberFormat currencyFormat,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Informasi Header',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              _buildApprovalBadge(header.isApproved),
            ],
          ),
          const SizedBox(height: 10),

          _buildInfoRow('Tanggal', _formatDisplayDate(header.tanggal)),
          _buildInfoRow('Customer', header.customer),
          _buildInfoRow('Perusahaan', header.perusahaan),
          _buildInfoRow('Sales', header.sales),
          _buildInfoRow('Tipe', header.tipe),
          _buildInfoRow('UP', header.up),
          _buildInfoRow('TTD', header.ttd),
          _buildInfoRow(
            'Status PPN',
            header.statusHarga == 1
                ? 'Sudah Termasuk PPN (INC PPN)'
                : 'Belum Termasuk PPN (EXC PPN)',
          ),

          // Note Block
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(79, 70, 229, 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color.fromRGBO(79, 70, 229, 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  header.note.trim().isNotEmpty ? header.note : '-',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          _buildInfoRow('Nominal', currencyFormat.format(header.nominal)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              (value == null || value.trim().isEmpty) ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Badge Approval Dokumen Penawaran (Konsisten dengan List Screen)
  Widget _buildApprovalBadge(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3.5,
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
            size: 13,
            color: isApproved
                ? const Color(0xFF059669)
                : const Color(0xFFD97706),
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? 'Sudah Diapprove' : 'Belum Diapprove',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isApproved
                  ? const Color(0xFF059669)
                  : const Color(0xFFC2410C),
            ),
          ),
        ],
      ),
    );
  }

  // Badge Status Item/Barang Penawaran (Konsisten dengan modul status & tracking)
  Widget _buildItemStatusBadge(String status) {
    final st = status.trim().toUpperCase();
    if (st.isEmpty || st == '-') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          '-',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (st) {
      case 'CLOSE':
      case 'ACC':
      case 'CONFIRM':
      case 'SELESAI':
        bgColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFFA7F3D0);
        textColor = const Color(0xFF059669);
        break;
      case 'BATAL':
      case 'CANCEL':
      case 'TOLAK':
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        textColor = const Color(0xFFDC2626);
        break;
      case 'WAIT':
      case 'PENDING':
        bgColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFED7AA);
        textColor = const Color(0xFFC2410C);
        break;
      case 'PARSIAL':
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF2563EB);
        break;
      case 'OPEN':
      default:
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        textColor = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        st,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // --- WIDGET KARTU ITEM RINCIAN BARANG ---
  Widget _buildDetailItemCard({
    required PenawaranDetailItem item,
    required int index,
    required NumberFormat currencyFormat,
  }) {
    final dimensionText = item.panjang > 0 || item.lebar > 0
        ? '${item.panjang.toInt()} x ${item.lebar.toInt()} cm'
        : (item.ukuran.isNotEmpty ? item.ukuran : '-');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Nama Barang & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${item.namaBarang.isNotEmpty ? item.namaBarang : '-'}',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildItemStatusBadge(item.status),
            ],
          ),

          // Meta 1: Bahan • Ukuran • Satuan
          const SizedBox(height: 4),
          Text(
            '${item.bahan.isNotEmpty ? item.bahan : '-'} • $dimensionText • ${item.satuan.isNotEmpty ? item.satuan : '-'}',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Meta 2: Qty x Harga
          const SizedBox(height: 2),
          Text(
            'Qty ${item.qty.toInt()} x ${currencyFormat.format(item.harga)}',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Total
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(item.total),
            style: const TextStyle(
              color: Color(0xFF4F46E5),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),

          // Remark Batal / Confirm
          if (item.ketBatal.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Batal: ${item.ketBatal}',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.ketConfirm.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Confirm: ${item.ketConfirm}',
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET KARTU ACTIVITY LOG ---
  Widget _buildActivityLogSectionCard(List<PenawaranActivityLog> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Log',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...logs.asMap().entries.map((entry) {
            final idx = entry.key;
            final log = entry.value;
            final isApproval = log.type.toUpperCase() == 'APPROVAL';
            final stateLabel = log.approvalState.isNotEmpty
                ? log.approvalState
                : '-';

            Color stateBgColor;
            Color stateBorderColor;
            Color stateColor;
            if (stateLabel == 'ACC') {
              stateBgColor = const Color(0xFFECFDF5);
              stateBorderColor = const Color(0xFFA7F3D0);
              stateColor = const Color(0xFF059669);
            } else if (stateLabel == 'WAIT') {
              stateBgColor = const Color(0xFFFFF7ED);
              stateBorderColor = const Color(0xFFFED7AA);
              stateColor = const Color(0xFFD97706);
            } else if (stateLabel == 'TOLAK') {
              stateBgColor = const Color(0xFFFEF2F2);
              stateBorderColor = const Color(0xFFFECACA);
              stateColor = const Color(0xFFDC2626);
            } else {
              stateBgColor = const Color(0xFFF1F5F9);
              stateBorderColor = const Color(0xFFE2E8F0);
              stateColor = const Color(0xFF64748B);
            }

            return Container(
              margin: EdgeInsets.only(top: idx == 0 ? 0 : 8),
              padding: EdgeInsets.only(top: idx == 0 ? 0 : 8),
              decoration: BoxDecoration(
                border: idx == 0
                    ? null
                    : const Border(
                        top: BorderSide(
                          color: Color.fromRGBO(15, 23, 42, 0.08),
                        ),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isApproval
                            ? 'Approval $stateLabel'
                            : 'Update Status Detail',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isApproval)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: stateBgColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: stateBorderColor,
                            ),
                          ),
                          child: Text(
                            stateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: stateColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDateTime(log.createdAt)} • ${log.user.isNotEmpty ? log.user : '-'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (log.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- WIDGET BOTTOM ACTION ---
  Widget _buildBottomAction({required bool isManager, required bool isSigned}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color.fromRGBO(15, 23, 42, 0.08)),
        ),
      ),
      child: isManager
          ? Row(
              children: [
                // Button Export PDF
                Expanded(
                  child: GestureDetector(
                    onTap: (_isExportingPdf || !isSigned)
                        ? () {
                            if (!isSigned) _showUnapprovedModal();
                          }
                        : _handleExportPdf,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSigned
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF94A3B8).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color.fromRGBO(79, 70, 229, 0.18),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isExportingPdf ? 'Export PDF...' : 'Eksport PDF',
                        style: TextStyle(
                          color: isSigned
                              ? Colors.white
                              : const Color(0xFFF8FAFC).withValues(alpha: 0.9),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Button Approve / Sudah Diapprove
                Expanded(
                  child: isSigned
                      ? Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFA7F3D0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF059669),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Sudah Diapprove',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: _isSubmittingApproval
                              ? null
                              : _showApproveDialog,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF047857),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.done_all,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Approve',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Ajukan Perubahan & Ubah Status
                Row(
                  children: [
                    // Button Ajukan Perubahan
                    Expanded(
                      child: GestureDetector(
                        onTap: isSigned
                            ? () {
                                AppToast.warning(
                                  context,
                                  'Penawaran sudah diapprove dan tidak dapat diajukan perubahan',
                                );
                              }
                            : _showRequestChangeDialog,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSigned
                                ? const Color(0xFFF1F5F9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSigned
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF4F46E5),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 18,
                                color: isSigned
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ajukan Perubahan',
                                style: TextStyle(
                                  color: isSigned
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button Ubah Status
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await context.push(
                            '/penawaran/${Uri.encodeComponent(_decodedNomor)}/status',
                            extra: _decodedNomor,
                          );
                          _fetchDetail();
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF0369A1)),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.published_with_changes,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Ubah Status',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: Full Width Eksport PDF
                GestureDetector(
                  onTap: _handleExportPdf,
                  child: Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSigned
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color.fromRGBO(79, 70, 229, 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _isExportingPdf ? 'Export PDF...' : 'Eksport PDF',
                      style: TextStyle(
                        color: isSigned
                            ? Colors.white
                            : const Color(0xFFF8FAFC).withValues(alpha: 0.9),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
