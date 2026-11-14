import 'package:flutter/material.dart';

class AppReloadButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final String? tooltip;
  final double size;
  final double iconSize;

  const AppReloadButton({
    super.key,
    required this.onTap,
    required this.isLoading,
    this.tooltip = 'Segarkan data',
    this.size = 42,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        width: size,
        height: size,
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
        child: isLoading
            ? SizedBox(
                width: iconSize - 2,
                height: iconSize - 2,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4F46E5),
                ),
              )
            : Icon(
                Icons.refresh_rounded,
                size: iconSize,
                color: const Color(0xFF4F46E5),
              ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
