import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularProgressAnimated extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final double progress;
  final Color color;
  final Color bgColor;
  final Color textColor;
  final Duration duration;

  const CircularProgressAnimated({
    super.key,
    this.size = 78,
    this.strokeWidth = 8,
    required this.progress,
    this.color = const Color(0xFF06B6D4),
    this.bgColor = const Color.fromRGBO(15, 23, 42, 0.08),
    this.textColor = const Color(0xFF0F172A),
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<CircularProgressAnimated> createState() =>
      _CircularProgressAnimatedState();
}

class _CircularProgressAnimatedState extends State<CircularProgressAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _setupAnimation();
    _controller.forward();
  }

  void _setupAnimation() {
    final target = (widget.progress / 100.0).clamp(0.0, 1.0);
    _animation = Tween<double>(begin: 0.0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant CircularProgressAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller.reset();
      _setupAnimation();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = math.max(0.0, widget.progress).toStringAsFixed(1);
    final fontSize = (widget.size / 5.2).clamp(10.0, 22.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CircularPainter(
                  progress: _animation.value,
                  strokeWidth: widget.strokeWidth,
                  color: widget.color,
                  bgColor: widget.bgColor,
                ),
              );
            },
          ),
          Text(
            '$displayText%',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: widget.textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color bgColor;

  _CircularPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Background
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress Arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
