import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/app_reload_button.dart';

class RekapVisitPlanDetailScreen extends ConsumerStatefulWidget {
  final int id;
  final bool canEdit;

  const RekapVisitPlanDetailScreen({
    super.key,
    required this.id,
    this.canEdit = true,
  });

  @override
  ConsumerState<RekapVisitPlanDetailScreen> createState() =>
      _RekapVisitPlanDetailScreenState();
}

class _RekapVisitPlanDetailScreenState
    extends ConsumerState<RekapVisitPlanDetailScreen> {
  final _noteController = TextEditingController();
  Map<String, dynamic>? _detail;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/visit-plan');
    }
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final repo = ref.read(visitRepositoryProvider);
    final data = await repo.getRekapVisitPlanDetail(widget.id);

    if (mounted) {
      setState(() {
        _detail = data;
        _noteController.text = data?['note']?.toString() ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppToast.error(context, 'Catatan keperluan tidak boleh kosong');
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(visitRepositoryProvider);
    final success = await repo.updateRekapVisitPlanNote(widget.id, note);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        AppToast.success(context, 'Berhasil disimpan');
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal menyimpan note');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final isTablet = ResponsiveHelper.isTablet(context);
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final cardPadding = isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.formWidth(context)),
                child: Column(
                  children: [
                    // 1. TOP HEADER (Responsif)
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleBack,
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
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Detail Visit Plan',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rincian jadwal & update keperluan',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppReloadButton(
                            onTap: _loadDetail,
                            isLoading: _isLoading,
                            tooltip: 'Segarkan data',
                            size: isDesktop ? 44 : 40,
                            iconSize: isDesktop ? 22 : 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. KONTEN DETAIL (Card Responsif)
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                            )
                          : _detail == null
                              ? const Center(
                                  child: Text(
                                    'Data visit plan tidak ditemukan.',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: 8,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(cardPadding),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(15, 23, 42, 0.04),
                                          blurRadius: 18,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Customer
                                        const Text(
                                          'Customer',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _detail!['cus_nama']?.toString() ??
                                                _detail!['cc_nama']?.toString() ??
                                                '-',
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Baris Info Tambahan (Kode & Tanggal Rencana)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              if (_detail!['cus_kode'] != null)
                                                Text(
                                                  'Kode: ${_detail!['cus_kode']}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              if (_detail!['tanggal_plan'] != null)
                                                Text(
                                                  'Rencana: ${_detail!['tanggal_plan']}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF4F46E5),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Keperluan
                                        const Text(
                                          'Keperluan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _noteController,
                                          enabled: widget.canEdit,
                                          maxLines: 5,
                                          decoration: InputDecoration(
                                            hintText: 'Tulis keperluan...',
                                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                            filled: true,
                                            fillColor: widget.canEdit ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Tombol Aksi (Adaptif Tablet/Desktop)
                                        if (widget.canEdit) ...[
                                          if (isTablet || isDesktop)
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: SizedBox(
                                                    height: 48,
                                                    child: TextButton(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: const Color(0xFF64748B),
                                                        backgroundColor: const Color(0xFFF1F5F9),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(14),
                                                        ),
                                                      ),
                                                      onPressed: _handleBack,
                                                      child: const Text(
                                                        'Kembali',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  flex: 3,
                                                  child: SizedBox(
                                                    height: 48,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF4F46E5),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(14),
                                                        ),
                                                      ),
                                                      onPressed: _isSubmitting ? null : _submitNote,
                                                      child: _isSubmitting
                                                          ? const SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                            )
                                                          : const Text(
                                                              'Simpan',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w800,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else ...[
                                            SizedBox(
                                              width: double.infinity,
                                              height: 48,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF4F46E5),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                ),
                                                onPressed: _isSubmitting ? null : _submitNote,
                                                child: _isSubmitting
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                      )
                                                    : const Text(
                                                        'Simpan',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 44,
                                              child: TextButton(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: const Color(0xFF64748B),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                ),
                                                onPressed: _handleBack,
                                                child: const Text(
                                                  'Kembali',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ] else ...[
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 12),
                                            child: Text(
                                              'Note tidak bisa diedit untuk role ini.',
                                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFF1F5F9),
                                                foregroundColor: const Color(0xFF334155),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                              ),
                                              onPressed: _handleBack,
                                              child: const Text(
                                                'Kembali',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
