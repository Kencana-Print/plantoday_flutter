import 'package:flutter/material.dart';

class SegmentItem {
  final int count;
  final Color color;

  const SegmentItem({required this.count, required this.color});
}

class SegmentedBar extends StatelessWidget {
  final List<SegmentItem> segments;
  final double height;
  final double borderRadius;

  const SegmentedBar({
    super.key,
    required this.segments,
    this.height = 6.0,
    this.borderRadius = 99.0,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.count);

    if (total <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: Row(
          children: segments.where((s) => s.count > 0).map((s) {
            return Expanded(
              flex: s.count,
              child: Container(color: s.color),
            );
          }).toList(),
        ),
      ),
    );
  }
}
