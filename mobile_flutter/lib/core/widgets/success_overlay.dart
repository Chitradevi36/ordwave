import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Full-screen success overlay with an animated check circle.
///
/// Usage:
/// ```dart
/// _showSuccessOverlay(
///   context,
///   title: 'Order Submitted!',
///   subtitle: 'Order #ORD-0042 is pending approval.',
///   onDone: () => context.go('/home/orders'),
/// );
/// ```
void showSuccessOverlay(
  BuildContext context, {
  required String title,
  String? subtitle,
  Duration displayDuration = const Duration(seconds: 2),
  VoidCallback? onDone,
}) {
  Navigator.of(context).push<void>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, animation, _) => FadeTransition(
        opacity: animation,
        child: _SuccessOverlayPage(
          title: title,
          subtitle: subtitle,
          displayDuration: displayDuration,
          onDone: onDone,
        ),
      ),
    ),
  );
}

class _SuccessOverlayPage extends StatefulWidget {
  const _SuccessOverlayPage({
    required this.title,
    this.subtitle,
    required this.displayDuration,
    this.onDone,
  });

  final String title;
  final String? subtitle;
  final Duration displayDuration;
  final VoidCallback? onDone;

  @override
  State<_SuccessOverlayPage> createState() => _SuccessOverlayPageState();
}

class _SuccessOverlayPageState extends State<_SuccessOverlayPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _checkProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );

    _ctrl.forward();

    Future.delayed(widget.displayDuration, () {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: OlColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OlColors.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _checkProgress,
                  builder: (_, __) => CustomPaint(
                    painter: _CheckmarkPainter(progress: _checkProgress.value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Opacity(
                opacity: _ctrl.value.clamp(0.0, 1.0),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws an animated white checkmark inside a circle.
class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Checkmark path: start bottom-left → mid → upper-right
    final path = Path()
      ..moveTo(cx - 22, cy)
      ..lineTo(cx - 6, cy + 14)
      ..lineTo(cx + 22, cy - 16);

    final metric = path.computeMetrics().first;
    final extracted = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}
