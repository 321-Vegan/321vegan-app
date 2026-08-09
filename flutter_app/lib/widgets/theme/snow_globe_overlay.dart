import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SnowGlobeOverlay extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final IconData? particleIcon;
  final String? particleAsset;
  final BorderRadius? borderRadius;

  /// Tint for icon particles and the plain-circle fallback. Defaults to
  /// white, which reads well on the vivid gradient card previews this was
  /// built for — callers placing it over a pale background (e.g. the app
  /// background) should pass a darker, theme-appropriate color instead.
  final Color particleColor;

  const SnowGlobeOverlay({
    super.key,
    required this.child,
    this.particleCount = 18,
    this.particleIcon,
    this.particleAsset,
    this.borderRadius,
    this.particleColor = Colors.white,
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

    _accelSub = accelerometerEventStream().listen((event) {
      _prevAccelX = _accelX;
      _prevAccelY = _accelY;
      _accelX = event.x;
      _accelY = event.y;

      // Detect shake: sudden acceleration change
      final deltaX = _accelX - _prevAccelX;
      final deltaY = _accelY - _prevAccelY;
      final magnitude = sqrt(deltaX * deltaX + deltaY * deltaY);

      if (magnitude > 1.5) {
        // Give each particle a unique random burst
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

  _Snowflake _createFlake(bool randomizeY) {
    return _Snowflake(
      x: _random.nextDouble(),
      y: randomizeY ? _random.nextDouble() : -_random.nextDouble() * 0.1,
      vx: 0,
      vy: 0,
      radius: 1.5 + _random.nextDouble() * 2.5,
      opacity: 0.3 + _random.nextDouble() * 0.5,
      shimmerPhase: _random.nextDouble() * 2 * pi,
      shimmerSpeed: 1.0 + _random.nextDouble() * 2.0,
      damping: 0.96 + _random.nextDouble() * 0.03, // each flake has unique drag
      rotationPhase: _random.nextDouble() * 2 * pi,
      rotationSpeed: 0.5 + _random.nextDouble() * 1.5,
    );
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    if (dt <= 0 || dt > 0.1) return;

    // Gentle tilt-based drift
    final tiltX = -_accelX / 9.8;
    final tiltY = _accelY / 9.8;

    for (final f in _flakes) {
      // Tilt influence
      f.vx += tiltX * 0.35 * dt;
      f.vy += tiltY * 0.35 * dt;

      // Very gentle settling downward
      f.vy += 0.02 * dt;

      // Per-particle damping
      f.vx *= f.damping;
      f.vy *= f.damping;

      // Clamp velocity
      f.vx = f.vx.clamp(-2.0, 2.0);
      f.vy = f.vy.clamp(-2.0, 2.0);

      // Update position
      f.x += f.vx * dt;
      f.y += f.vy * dt;

      // Bounce off edges
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

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
      child: Stack(
        children: [
          widget.child,
          if (widget.particleIcon != null || widget.particleAsset != null)
            ...List.generate(_flakes.length, (i) {
              final f = _flakes[i];
              final shimmer =
                  0.7 + 0.3 * sin(elapsed * f.shimmerSpeed + f.shimmerPhase);
              final size = f.radius * 5;
              return Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(f.x * 2 - 1, f.y * 2 - 1),
                    child: Transform.rotate(
                      angle: elapsed * f.rotationSpeed + f.rotationPhase,
                      child: Opacity(
                        opacity: (f.opacity * shimmer).clamp(0.0, 1.0),
                        child: widget.particleIcon != null
                            ? Icon(
                                widget.particleIcon,
                                size: size,
                                color: widget.particleColor,
                              )
                            : Image.asset(
                                widget.particleAsset!,
                                width: size,
                                height: size,
                                // A missing/unregistered asset would otherwise
                                // retry resolution on every animation frame
                                // (this repaints at 60fps) instead of failing
                                // once — silently drop that particle instead.
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

  _SnowGlobePainter(
      {required this.flakes, required this.time, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flakes) {
      final shimmer = 0.7 + 0.3 * sin(time * f.shimmerSpeed + f.shimmerPhase);
      final paint = Paint()
        ..color = color.withValues(alpha: f.opacity * shimmer)
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

  _Snowflake({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.shimmerPhase,
    required this.shimmerSpeed,
    required this.damping,
    required this.rotationPhase,
    required this.rotationSpeed,
  });
}
