import 'dart:async';
import 'dart:math';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../themes/app_shapes.dart';

class SnowGlobeOverlay extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final IconData? particleIcon;

  /// Asset paths particles are randomly drawn from; each keeps its pick for
  /// its lifetime. Ignored when [particleIcon] is set.
  final List<String>? particleAssets;
  final SmoothBorderRadius? borderRadius;

  /// Tint for icon particles and the plain-circle fallback. Defaults to
  /// white (works on vivid gradients); pass a darker color over pale
  /// backgrounds like the app background.
  final Color particleColor;

  /// Multiplier applied on top of each particle's own random base opacity;
  /// 1.0 keeps the default range, lower values make particles more subtle.
  final double particleOpacity;

  /// Random per-particle radius range, picked once at creation. Drives
  /// rendered size directly for the plain-circle fallback, `radius * 5`
  /// for icon/image particles.
  final double particleMinRadius;
  final double particleMaxRadius;

  const SnowGlobeOverlay({
    super.key,
    required this.child,
    this.particleCount = 18,
    this.particleIcon,
    this.particleAssets,
    this.borderRadius,
    this.particleColor = Colors.white,
    this.particleOpacity = 1.0,
    this.particleMinRadius = 1.5,
    this.particleMaxRadius = 4.0,
  });

  @override
  State<SnowGlobeOverlay> createState() => _SnowGlobeOverlayState();
}

class _SnowGlobeOverlayState extends State<SnowGlobeOverlay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late List<_Snowflake> _flakes;
  final Random _random = Random();
  StreamSubscription? _accelSub;

  double _accelX = 0;
  double _accelY = 0;
  double _prevAccelX = 0;
  double _prevAccelY = 0;

  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _flakes = List.generate(widget.particleCount, (_) => _createFlake(true));

    _ticker = createTicker(_onTick)..start();

    // userAccelerometerEventStream excludes gravity (unlike
    // accelerometerEventStream) — otherwise the constant ~1g at rest would
    // read as constant downward tilt, making particles fall continuously.
    _accelSub = userAccelerometerEventStream().listen((event) {
      _prevAccelX = _accelX;
      _prevAccelY = _accelY;
      _accelX = event.x;
      _accelY = event.y;

      final deltaX = _accelX - _prevAccelX;
      final deltaY = _accelY - _prevAccelY;
      final magnitude = sqrt(deltaX * deltaX + deltaY * deltaY);

      if (magnitude > 1.5) {
        final strength = (magnitude / 7.0).clamp(0.3, 1.0);
        for (final f in _flakes) {
          final angle = _random.nextDouble() * 2 * pi;
          final force = strength * (0.4 + _random.nextDouble() * 0.6);
          f.vx += cos(angle) * force;
          f.vy += sin(angle) * force;
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant SnowGlobeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.particleCount != widget.particleCount ||
        oldWidget.particleMinRadius != widget.particleMinRadius ||
        oldWidget.particleMaxRadius != widget.particleMaxRadius) {
      // Count/radius range changed (e.g. switching season) — the old
      // flakes no longer match, so start over.
      _flakes = List.generate(widget.particleCount, (_) => _createFlake(true));
      return;
    }

    if (!listEquals(oldWidget.particleAssets, widget.particleAssets)) {
      // Asset list changed length (e.g. summer's 3 fruits -> spring's 2) —
      // re-pick each flake's asset so a stale index doesn't run off the end.
      final assets = widget.particleAssets;
      for (final f in _flakes) {
        f.assetIndex = assets != null && assets.isNotEmpty
            ? _random.nextInt(assets.length)
            : 0;
      }
    }
  }

  _Snowflake _createFlake(bool randomizeY) {
    final assets = widget.particleAssets;
    return _Snowflake(
      x: _random.nextDouble(),
      y: randomizeY ? _random.nextDouble() : -_random.nextDouble() * 0.1,
      vx: 0,
      vy: 0,
      radius: widget.particleMinRadius +
          _random.nextDouble() *
              (widget.particleMaxRadius - widget.particleMinRadius),
      opacity: 0.3 + _random.nextDouble() * 0.5,
      shimmerPhase: _random.nextDouble() * 2 * pi,
      shimmerSpeed: 0.6 + _random.nextDouble() * 1.2,
      // Picked once per particle so it keeps the same image for its
      // lifetime instead of flickering between assets every frame.
      assetIndex: assets != null && assets.isNotEmpty
          ? _random.nextInt(assets.length)
          : 0,
      damping: 0.96 + _random.nextDouble() * 0.03,
      rotationPhase: _random.nextDouble() * 2 * pi,
      rotationSpeed: 0.25 + _random.nextDouble() * 0.75,
    );
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    if (dt <= 0 || dt > 0.1) return;

    // Gravity-free user-acceleration sits near 0 at rest, so this divisor
    // is tuned to that smaller range rather than gravity's ~9.8.
    final tiltX = -_accelX / 4.0;
    final tiltY = _accelY / 4.0;

    for (final f in _flakes) {
      f.vx += tiltX * 0.15 * dt;
      f.vy += tiltY * 0.15 * dt;

      f.vy += 0.02 * dt;

      f.vx *= f.damping;
      f.vy *= f.damping;

      f.vx = f.vx.clamp(-1.0, 1.0);
      f.vy = f.vy.clamp(-1.0, 1.0);

      f.x += f.vx * dt;
      f.y += f.vy * dt;

      if (f.x < 0) {
        f.x = 0;
        f.vx = f.vx.abs() * 0.4;
      } else if (f.x > 1) {
        f.x = 1;
        f.vx = -f.vx.abs() * 0.4;
      }

      if (f.y < 0) {
        f.y = 0;
        f.vy = f.vy.abs() * 0.4;
      } else if (f.y > 1) {
        f.y = 1;
        f.vy = -f.vy.abs() * 0.4;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _lastTick.inMilliseconds / 1000.0;

    return ClipSmoothRect(
      radius: widget.borderRadius ?? squircleRadius(10),
      child: Stack(
        children: [
          widget.child,
          if (widget.particleIcon != null ||
              (widget.particleAssets != null &&
                  widget.particleAssets!.isNotEmpty))
            ...List.generate(_flakes.length, (i) {
              final f = _flakes[i];
              final size = f.radius * 5;
              return Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(f.x * 2 - 1, f.y * 2 - 1),
                    child: Transform.rotate(
                      angle: elapsed * f.rotationSpeed + f.rotationPhase,
                      child: Opacity(
                        opacity: (1 * widget.particleOpacity).clamp(0.0, 1.0),
                        child: widget.particleIcon != null
                            ? Icon(
                                widget.particleIcon,
                                size: size,
                                color: widget.particleColor,
                              )
                            : Image.asset(
                                widget.particleAssets![f.assetIndex],
                                width: size,
                                height: size,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            })
          else
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SnowGlobePainter(
                    flakes: _flakes,
                    time: elapsed,
                    color: widget.particleColor,
                    opacity: widget.particleOpacity,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SnowGlobePainter extends CustomPainter {
  final List<_Snowflake> flakes;
  final double time;
  final Color color;
  final double opacity;

  _SnowGlobePainter({
    required this.flakes,
    required this.time,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flakes) {
      final paint = Paint()
        ..color = color.withValues(alpha: (f.opacity * opacity).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(f.x * size.width, f.y * size.height),
        f.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SnowGlobePainter oldDelegate) => true;
}

class _Snowflake {
  double x;
  double y;
  double vx;
  double vy;
  final double radius;
  final double opacity;
  final double shimmerPhase;
  final double shimmerSpeed;
  final double damping;
  final double rotationPhase;
  final double rotationSpeed;
  int assetIndex;

  _Snowflake({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.shimmerPhase,
    required this.shimmerSpeed,
    required this.assetIndex,
    required this.damping,
    required this.rotationPhase,
    required this.rotationSpeed,
  });
}
