import 'package:flutter/material.dart';

/// Modal dialog konfirmasi form persis dengan implementasi React Native:
/// (confirmModalCard, confirmModalHeader, confirmSummaryBox, confirmModalActions)
Future<bool> showFormConfirmDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  Color iconColor = const Color(0xFF0284C7),
  Color iconBgColor = const Color(0xFFE0F2FE),
  required List<MapEntry<String, String>> summaryItems,
  String confirmText = 'Konfirmasi',
  String cancelText = 'Batal',
  Color confirmColor = const Color(0xFF15803D), // Default hijau seperti di React Native
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color.fromRGBO(15, 23, 42, 0.65), // confirmModalOverlay
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380), // maxWidth: 380
        child: Container(
          // confirmModalCard
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20), // borderRadius: 20
            border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.14),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20), // padding: 20
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // confirmModalHeader
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    // confirmModalIconWrap (48x48, borderRadius: 24)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // confirmModalTitle
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A), // THEME.ink
                    ),
                  ),

                  // confirmModalSub
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // confirmSummaryBox
              if (summaryItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12), // padding: 12
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // backgroundColor: '#f8fafc'
                    borderRadius: BorderRadius.circular(12), // borderRadius: 12
                    border: Border.all(
                      color: const Color(0xFFE2E8F0), // borderColor: '#e2e8f0'
                    ),
                  ),
                  child: Column(
                    children: List.generate(summaryItems.length, (index) {
                      final item = summaryItems[index];
                      final isLast = index == summaryItems.length - 1;

                      // confirmSummaryRow
                      return Container(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : 6,
                          top: index == 0 ? 0 : 6,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFF1F5F9), // borderBottomColor: '#f1f5f9'
                                  ),
                                ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // confirmSummaryLabel
                            Text(
                              item.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // confirmSummaryVal
                            Expanded(
                              child: Text(
                                item.value,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 18),

              // confirmModalActions (flexDirection: 'row', gap: 10)
              Row(
                children: [
                  // confirmBtnCancel (flex: 1, paddingVertical: 12, borderRadius: 12, backgroundColor: '#f1f5f9')
                  Expanded(
                    flex: 10,
                    child: Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, false),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569), // confirmBtnCancelText
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // confirmBtnSubmit (flex: 1.4, paddingVertical: 12, borderRadius: 12, backgroundColor: '#15803d')
                  Expanded(
                    flex: 14,
                    child: Material(
                      color: confirmColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white, // confirmBtnSubmitText
                              ),
                            ),
                          ),
                        ),
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

  return result ?? false;
}
