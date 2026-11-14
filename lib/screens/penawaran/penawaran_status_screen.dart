import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/penawaran_model.dart';
import '../../repositories/penawaran_repository.dart';

class PenawaranStatusUpdateItem {
  final String id;
  String status;
  String ketBatal;
  String ketConfirm;

  PenawaranStatusUpdateItem({
    required this.id,
    required this.status,
    this.ketBatal = '',
    this.ketConfirm = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'ket_batal': ketBatal,
        'ket_confirm': ketConfirm,
      };
}

class PenawaranStatusScreen extends ConsumerStatefulWidget {
  final String nomor;

  const PenawaranStatusScreen({super.key, required this.nomor});

  @override
  ConsumerState<PenawaranStatusScreen> createState() =>
      _PenawaranStatusScreenState();
}

class _PenawaranStatusScreenState extends ConsumerState<PenawaranStatusScreen> {
  bool _isLoading = false;
  bool _isSubmitting = false;

  String _approvalState = '';
  List<PenawaranDetailItem> _details = [];
  final Map<String, PenawaranStatusUpdateItem> _updates = {};

  List<Map<String, String>> _masterBatal = [];
  List<Map<String, String>> _masterConfirm = [];

  // Pilihan status persis React Native
  final List<Map<String, String>> _statusOptions = [
    {'label': 'OPEN', 'value': 'OPEN'},
    {'label': 'BATAL', 'value': 'BATAL'},
    {'label': 'CLOSE', 'value': 'CLOSE'},
    {'label': '(Kosong)', 'value': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final detailData = await repo.getPenawaranDetail(widget.nomor);
    final batal = await repo.getMasterPenawaranBatal();
    final confirm = await repo.getMasterPenawaranConfirm();

    if (mounted) {
      final items = detailData?.details ?? [];
      final header = detailData?.header;

      _updates.clear();
      for (final it in items) {
        _updates[it.id] = PenawaranStatusUpdateItem(
          id: it.id,
          status: it.status.trim().toUpperCase(),
          ketBatal: it.ketBatal.trim(),
          ketConfirm: it.ketConfirm.trim(),
        );
      }

      setState(() {
        _details = items;
        _approvalState = header?.approvalState.trim().toUpperCase() ?? '';
        _masterBatal = batal;
        _masterConfirm = confirm;
        _isLoading = false;
      });
    }
  }

  void _showOptionPicker({
    required String title,
    required List<Map<String, String>> options,
    required ValueChanged<String> onSelected,
  }) {
    if (_approvalState == 'WAIT') {
      AppToast.info(
        context,
        'Penawaran sedang proses approval (WAIT), perubahan status detail dikunci.',
      );
      return;
    }

    if (options.isEmpty) {
      AppToast.info(context, 'Pilihan opsi belum tersedia.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 14, color: Color(0xFFF1F5F9)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, idx) {
                    final opt = options[idx];
                    final label = opt['label'] ?? '';
                    final val = opt['value'] ?? '';

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(val);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validateAndConfirm() {
    if (_approvalState == 'WAIT') {
      AppToast.info(
        context,
        'Penawaran sedang proses approval (WAIT), perubahan status detail dikunci.',
      );
      return;
    }

    // Validasi: Status BATAL wajib diisi alasannya persis React Native
    for (final it in _details) {
      final upd = _updates[it.id];
      if (upd?.status == 'BATAL' && (upd?.ketBatal.trim().isEmpty ?? true)) {
        AppToast.error(
          context,
          'Item #${it.urutan} (${it.namaBarang}): Status BATAL wajib diisi alasannya',
        );
        return;
      }
    }

    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Yakin ingin menyimpan perubahan status detail penawaran ini?',
          style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitStatusUpdates();
            },
            child: const Text('Simpan',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitStatusUpdates() async {
    setState(() => _isSubmitting = true);

    final repo = ref.read(penawaranRepositoryProvider);
    final payloadList = _updates.values.map((u) => u.toJson()).toList();
    final success = await repo.updatePenawaranStatusDetail(
      widget.nomor,
      payloadList,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        AppToast.success(context, 'Status detail berhasil diubah');
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal menyimpan status penawaran');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final isLocked = _approvalState == 'WAIT';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                ResponsiveHelper.horizontalPadding(context);
            final maxContainerWidth = ResponsiveHelper.formWidth(context);

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
                            child: Text(
                              'Ubah Status Item',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 38),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. KONTEN FORM
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header Card (No. Penawaran)
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                            15, 23, 42, 0.08),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(15, 23, 42, 0.03),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'No. Penawaran: ${widget.nomor}',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Banner Kunci WAIT
                                  if (isLocked) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFFCD34D)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.lock_outline_rounded,
                                              size: 18,
                                              color: Color(0xFF92400E)),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Approval WAIT: status detail sementara tidak dapat diubah.',
                                              style: TextStyle(
                                                color: Color(0xFF92400E),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // List Item Cards Persis React Native
                                  if (_details.isEmpty)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Text(
                                          'Tidak ada item detail.',
                                          style: TextStyle(
                                              color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    )
                                  else
                                    ..._details.map((item) {
                                      final upd = _updates[item.id];
                                      final currentStatus =
                                          upd?.status ?? '';

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color.fromRGBO(
                                                15, 23, 42, 0.08),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color.fromRGBO(
                                                  15, 23, 42, 0.03),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Title: No. Nama Barang
                                            Text(
                                              '${item.urutan}. ${item.namaBarang}',
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),

                                            // Qty x Harga
                                            Text(
                                              'Qty: ${item.qty.toInt()} x Rp ${currencyFormat.format(item.harga).trim()}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 12),

                                            // 1. Form Group: Status
                                            _buildFormGroupLabel('Status'),
                                            const SizedBox(height: 6),
                                            _buildPickerButton(
                                              text: currentStatus.isNotEmpty
                                                  ? currentStatus
                                                  : 'Pilih Status...',
                                              textColor: currentStatus == 'CLOSE'
                                                  ? const Color(0xFF059669)
                                                  : currentStatus == 'BATAL'
                                                      ? const Color(0xFFDC2626)
                                                      : currentStatus == 'OPEN'
                                                          ? const Color(0xFFD97706)
                                                          : null,
                                              bgColor: currentStatus == 'CLOSE'
                                                  ? const Color(0xFFECFDF5)
                                                  : currentStatus == 'BATAL'
                                                      ? const Color(0xFFFEF2F2)
                                                      : currentStatus == 'OPEN'
                                                          ? const Color(0xFFFFFBEB)
                                                          : null,
                                              borderColor: currentStatus == 'CLOSE'
                                                  ? const Color(0xFFA7F3D0)
                                                  : currentStatus == 'BATAL'
                                                      ? const Color(0xFFFECACA)
                                                      : currentStatus == 'OPEN'
                                                          ? const Color(0xFFFDE68A)
                                                          : null,
                                              isDisabled:
                                                  isLocked || _isSubmitting,
                                              onTap: () {
                                                _showOptionPicker(
                                                  title: 'Pilih Status',
                                                  options: _statusOptions,
                                                  onSelected: (val) {
                                                    setState(() {
                                                      upd?.status = val;
                                                      if (val != 'BATAL') {
                                                        upd?.ketBatal = '';
                                                      }
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 12),

                                            // 2. Form Group: Alasan Batal (Hanya jika status == BATAL)
                                            if (currentStatus == 'BATAL') ...[
                                              _buildFormGroupLabel(
                                                'Alasan Batal',
                                                isRequired: true,
                                              ),
                                              const SizedBox(height: 6),
                                              _buildPickerButton(
                                                text: upd?.ketBatal.isNotEmpty ==
                                                        true
                                                    ? upd!.ketBatal
                                                    : '-- Pilih Alasan --',
                                                isDisabled:
                                                    isLocked || _isSubmitting,
                                                onTap: () {
                                                  _showOptionPicker(
                                                    title: 'Pilih Alasan Batal',
                                                    options: _masterBatal
                                                        .map((b) => {
                                                              'label': b['nama'] ??
                                                                  b['kode'] ??
                                                                  '',
                                                              'value': b['nama'] ??
                                                                  b['kode'] ??
                                                                  '',
                                                            })
                                                        .toList(),
                                                    onSelected: (val) {
                                                      setState(() {
                                                        upd?.ketBatal = val;
                                                      });
                                                    },
                                                  );
                                                },
                                              ),
                                              if (_masterBatal.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                      top: 4, left: 2),
                                                  child: Text(
                                                    'Master alasan batal belum tersedia.',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                            ],

                                            // 3. Form Group: Konfirmasi (Jika status != BATAL)
                                            if (currentStatus != 'BATAL') ...[
                                              _buildFormGroupLabel(
                                                'Konfirmasi',
                                                isRequired: true,
                                              ),
                                              const SizedBox(height: 6),
                                              _buildPickerButton(
                                                text: upd?.ketConfirm.isNotEmpty ==
                                                        true
                                                    ? upd!.ketConfirm
                                                    : '-- Pilih Konfirmasi --',
                                                isDisabled:
                                                    isLocked || _isSubmitting,
                                                onTap: () {
                                                  _showOptionPicker(
                                                    title:
                                                        'Pilih Jenis Konfirmasi',
                                                    options: _masterConfirm
                                                        .map((c) => {
                                                              'label': c['nama'] ??
                                                                  c['kode'] ??
                                                                  '',
                                                              'value': c['nama'] ??
                                                                  c['kode'] ??
                                                                  '',
                                                            })
                                                        .toList(),
                                                    onSelected: (val) {
                                                      setState(() {
                                                        upd?.ketConfirm = val;
                                                      });
                                                    },
                                                  );
                                                },
                                              ),
                                              if (_masterConfirm.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                      top: 4, left: 2),
                                                  child: Text(
                                                    'Master konfirmasi belum tersedia.',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                    ),

                    // 3. BOTTOM BUTTON CONTAINER (Batal Merah & Simpan Biru/Ungu Persis React Native)
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
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => context.pop(),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
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
                                onPressed: (_isSubmitting || isLocked)
                                    ? null
                                    : _validateAndConfirm,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Simpan',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
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

  Widget _buildFormGroupLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required String text,
    required bool isDisabled,
    required VoidCallback onTap,
    Color? textColor,
    Color? bgColor,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? const Color(0xFFF1F5F9).withValues(alpha: 0.6)
              : (bgColor ?? const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor ?? const Color.fromRGBO(15, 23, 42, 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDisabled
                      ? const Color(0xFF94A3B8)
                      : (textColor ?? const Color(0xFF0F172A)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: isDisabled
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF4F46E5),
            ),
          ],
        ),
      ),
    );
  }
}
