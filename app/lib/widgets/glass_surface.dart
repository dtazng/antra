import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:antra/theme/app_theme.dart';

/// Shadow depth presets for [GlassSurface].
enum GlassElevation { flat, card, modal }

/// Visual style presets for [GlassSurface].
enum GlassStyle { card, bar, modal, chip, hero }

/// Reusable frosted glass card surface.
///
/// Renders `BackdropFilter → ClipRRect → Container` with a luminous border
/// and diffuse two-layer shadow. Tap feedback scales the surface to 0.97 over
/// [AntraMotion.tapFeedback] duration.
///
/// Usage:
/// ```dart
/// GlassSurface(
///   style: GlassStyle.card,
///   onTap: () => ...,
///   child: myContent,
/// )
/// ```
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.style = GlassStyle.card,
    this.padding,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final GlassStyle style;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// When provided, overrides the [GlassStyle] default border radius.
  final BorderRadius? borderRadius;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: AntraMotion.tapFeedback,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapController, curve: AntraMotion.tapCurve),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    // ignore: discarded_futures
    if (widget.onTap != null) _tapController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    // ignore: discarded_futures
    _tapController.reverse();
    widget.onTap?.call();
  }

  // ignore: discarded_futures
  void _onTapCancel() => _tapController.reverse();

  @override
  Widget build(BuildContext context) {
    final props = _GlassProps.of(widget.style);
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(16);
    final effectiveRadius = widget.borderRadius ?? props.borderRadius;

    Widget surface = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: props.tintOpacity),
        borderRadius: effectiveRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: AntraColors.glassBorderOpacity),
          width: 1,
        ),
        boxShadow: props.elevation == GlassElevation.flat
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: AntraColors.glassShadowAmbientOpacity,
                  ),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: AntraColors.glassShadowFillOpacity,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: widget.child,
    );

    surface = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: props.blurSigma,
          sigmaY: props.blurSigma,
        ),
        child: surface,
      ),
    );

    if (widget.onTap != null) {
      surface = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(scale: _scaleAnim, child: surface),
      );
    }

    return RepaintBoundary(child: surface);
  }
}

// ─── Props lookup ─────────────────────────────────────────────────────────────

class _GlassProps {
  final double blurSigma;
  final double tintOpacity;
  final BorderRadius borderRadius;
  final GlassElevation elevation;

  const _GlassProps({
    required this.blurSigma,
    required this.tintOpacity,
    required this.borderRadius,
    required this.elevation,
  });

  static _GlassProps of(GlassStyle style) {
    switch (style) {
      case GlassStyle.card:
        return _GlassProps(
          blurSigma: 12,
          tintOpacity: AntraColors.glassTintOpacityCard,
          borderRadius: BorderRadius.circular(AntraRadius.card),
          elevation: GlassElevation.card,
        );
      case GlassStyle.bar:
        return _GlassProps(
          blurSigma: 10,
          tintOpacity: AntraColors.glassTintOpacityBar,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AntraRadius.chip),
          ),
          elevation: GlassElevation.flat,
        );
      case GlassStyle.modal:
        return _GlassProps(
          blurSigma: 15,
          tintOpacity: AntraColors.glassTintOpacityModal,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AntraRadius.modal),
          ),
          elevation: GlassElevation.modal,
        );
      case GlassStyle.chip:
        return _GlassProps(
          blurSigma: 8,
          tintOpacity: AntraColors.glassTintOpacityChip,
          borderRadius: BorderRadius.circular(AntraRadius.chip),
          elevation: GlassElevation.flat,
        );
      case GlassStyle.hero:
        return _GlassProps(
          blurSigma: 12,
          tintOpacity: AntraColors.glassTintOpacityHero,
          borderRadius: BorderRadius.circular(24),
          elevation: GlassElevation.card,
        );
    }
  }
}
