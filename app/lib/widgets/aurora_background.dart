import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:antra/theme/app_theme.dart';

/// Selects which gradient composition [AuroraBackground] renders.
enum AuroraVariant {
  dayView,
  people,
  collections,
  search,
  review,
  modal,
}

/// Full-bleed animated aurora gradient background.
///
/// Renders behind all other content on a screen. Animates with a 30-second
/// sine-wave cycle. Respects [MediaQueryData.disableAnimations] — when true
/// the gradient renders statically at the midpoint position.
///
/// Usage:
/// ```dart
/// Scaffold(
///   appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, ...),
///   body: AuroraBackground(
///     variant: AuroraVariant.dayView,
///     child: ListView(...),
///   ),
/// )
/// ```
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.variant,
    required this.child,
  });

  final AuroraVariant variant;
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AntraMotion.backgroundCycle,
    );
    // We start/stop in didChangeDependencies after reading MediaQuery.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
      // Snap to midpoint for a stable static gradient.
      if (_controller.value == 0.0) _controller.value = 0.5;
    } else {
      if (!_controller.isAnimating) {
        // TickerFuture intentionally not awaited — animation runs until disposed.
        // ignore: discarded_futures
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AuroraPainter(
            variant: widget.variant,
            progress: _controller.value,
          ),
          child: child,
        );
      },
      // Pass child unchanged so it is not rebuilt on every animation frame.
      child: widget.child,
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.variant, required this.progress});

  final AuroraVariant variant;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Sine-wave interpolation ensures a seamless loop: f(0) == f(1).
    final t = math.sin(progress * 2 * math.pi) * 0.5 + 0.5;

    final stops = _stopsForVariant(t);
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: stops,
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    // Second diagonal sweep for depth.
    final paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.lerp(
          const Alignment(-0.5, -0.8),
          const Alignment(0.5, 0.2),
          t,
        )!,
        radius: 1.4,
        colors: _accentForVariant(t),
        stops: const [0.0, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(rect, paint2);
  }

  List<Color> _stopsForVariant(double t) {
    switch (variant) {
      case AuroraVariant.dayView:
        return [
          Color.lerp(AntraColors.auroraDeepNavy, AntraColors.auroraNavy, t)!,
          Color.lerp(AntraColors.auroraIndigo, AntraColors.auroraViolet, t)!,
          Color.lerp(AntraColors.auroraViolet, AntraColors.auroraIndigo, t)!,
        ];
      case AuroraVariant.people:
        return [
          Color.lerp(AntraColors.auroraNavy, AntraColors.auroraIndigo, t)!,
          Color.lerp(AntraColors.auroraViolet, AntraColors.auroraIndigo, t)!,
          Color.lerp(
            AntraColors.auroraCoralHint.withValues(alpha: 0.6),
            AntraColors.auroraMagenta.withValues(alpha: 0.4),
            t,
          )!,
        ];
      case AuroraVariant.collections:
        return [
          Color.lerp(AntraColors.auroraDeepNavy, AntraColors.auroraNavy, t)!,
          Color.lerp(AntraColors.auroraIndigo, AntraColors.auroraNavy, t)!,
          Color.lerp(AntraColors.auroraTeal, AntraColors.auroraIndigo, t)!,
        ];
      case AuroraVariant.search:
        return [
          Color.lerp(AntraColors.auroraDeepNavy, AntraColors.auroraNavy, t)!,
          Color.lerp(
            AntraColors.auroraElectricBlue,
            AntraColors.auroraIndigo,
            t,
          )!,
          Color.lerp(AntraColors.auroraIndigo, AntraColors.auroraViolet, t)!,
        ];
      case AuroraVariant.review:
        return [
          Color.lerp(AntraColors.auroraIndigo, AntraColors.auroraViolet, t)!,
          Color.lerp(AntraColors.auroraTeal, AntraColors.auroraIndigo, t)!,
          Color.lerp(AntraColors.auroraViolet, AntraColors.auroraDeepNavy, t)!,
        ];
      case AuroraVariant.modal:
        return [
          Color.lerp(
            AntraColors.auroraDeepNavy,
            AntraColors.auroraNavy.withValues(alpha: 0.95),
            t,
          )!,
          Color.lerp(
            AntraColors.auroraViolet.withValues(alpha: 0.85),
            AntraColors.auroraIndigo.withValues(alpha: 0.9),
            t,
          )!,
          Color.lerp(AntraColors.auroraDeepNavy, AntraColors.auroraNavy, t)!,
        ];
    }
  }

  List<Color> _accentForVariant(double t) {
    switch (variant) {
      case AuroraVariant.dayView:
        return [
          AntraColors.auroraMagenta.withValues(alpha: 0.15 + t * 0.10),
          Colors.transparent,
        ];
      case AuroraVariant.people:
        return [
          AntraColors.auroraCoralHint.withValues(alpha: 0.12 + t * 0.08),
          Colors.transparent,
        ];
      case AuroraVariant.collections:
        return [
          AntraColors.auroraTeal.withValues(alpha: 0.12 + t * 0.08),
          Colors.transparent,
        ];
      case AuroraVariant.search:
        return [
          AntraColors.auroraElectricBlue.withValues(alpha: 0.15 + t * 0.10),
          Colors.transparent,
        ];
      case AuroraVariant.review:
        return [
          AntraColors.auroraTeal.withValues(alpha: 0.12 + t * 0.08),
          Colors.transparent,
        ];
      case AuroraVariant.modal:
        return [
          AntraColors.auroraViolet.withValues(alpha: 0.20),
          Colors.transparent,
        ];
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.progress != progress || old.variant != variant;
}
