import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../models/product_of_interest.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_card.dart';

class ProductFoundModal extends StatefulWidget {
  final ProductOfInterest product;
  final bool isNewDiscovery;
  final VoidCallback? onClose;

  /// Called the instant the close animation finishes — the moment the card
  /// visually lands in the Vegandex button — so the caller can react (e.g.
  /// make the button itself buzz/shake) right on impact.
  final VoidCallback? onArrival;

  const ProductFoundModal({
    super.key,
    required this.product,
    this.isNewDiscovery = true,
    this.onClose,
    this.onArrival,
  });

  @override
  State<ProductFoundModal> createState() => _ProductFoundModalState();
}

class _ProductFoundModalState extends State<ProductFoundModal>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterFade;

  // Drives the close animation — the card shrinks and flies up into the
  // Vegandex button in the top-right corner instead of just fading out.
  late final AnimationController _exitController;
  late final Animation<double> _exitMotion;
  late final Animation<double> _exitFade;

  // Measures the card's actual rendered size so the translate offset can
  // compensate for the top-right-anchored scale below (see build()) and
  // land the shrink point exactly on the button, not half a card-width off.
  final GlobalKey _cardBoundsKey = GlobalKey();

  final baseUrl = dotenv.env['API_BASE_URL'];

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..forward();
    _enterScale =
        CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    _enterFade =
        CurvedAnimation(parent: _enterController, curve: Curves.easeOut);

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    // Motion (position/scale/rotation) runs the full duration with a sharp
    // acceleration near the end — like something being yanked into a drain
    // — while opacity is held near 1 until the very last moment, then drops
    // fast. Without that split the card was visibly fading the whole trip,
    // reading as "dissolving" rather than "sucked into the button".
    _exitMotion =
        CurvedAnimation(parent: _exitController, curve: Curves.easeInQuart);
    _exitFade = CurvedAnimation(
      parent: _exitController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _enterController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    if (_exitController.isAnimating) return;
    await _exitController.forward();
    widget.onArrival?.call();
    widget.onClose?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Approximate on-screen position of the Vegandex button (top row, right
    // edge — see scan.dart's _buildVegandexButton) so the close animation
    // reads as the card flying up and shrinking into it, rather than a
    // generic fade-out.
    final mq = MediaQuery.of(context);
    final targetDx = mq.size.width / 2 - 120.w;
    final targetDy = mq.padding.top + 24 + 72.w - mq.size.height / 2;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _exitController]),
        builder: (context, child) {
          final motionT = _exitMotion.value;
          final fadeT = _exitFade.value;
          final barrierOpacity = _enterFade.value * (1 - fadeT);
          final cardOpacity = _enterFade.value * (1 - fadeT);
          final baseScale = _enterScale.value * (1 - motionT) + 0.04 * motionT;
          // Mild stretch toward the target as it travels (peaking
          // mid-flight), on top of the overall shrink.
          final stretch = sin(motionT * pi).clamp(0.0, 1.0) * 0.35;
          final scaleX = baseScale * (1 - stretch);
          final scaleY = baseScale * (1 + stretch);

          // The scale below pivots on the card's top-right corner, which
          // stays fixed on screen at (halfW, -halfH) from center as long as
          // nothing else moves it — so the translate has to travel that
          // extra distance too, or the corner (and the shrink point) ends
          // up half a card-width past the button instead of on it.
          final cardBox =
              _cardBoundsKey.currentContext?.findRenderObject() as RenderBox?;
          final cardSize =
              (cardBox != null && cardBox.hasSize) ? cardBox.size : Size.zero;
          final endDx = targetDx - cardSize.width / 2;
          final endDy = targetDy + cardSize.height / 2;
          // Horizontal and vertical motion ease at slightly different
          // rates so the card arcs into the corner instead of sliding
          // along a perfectly straight diagonal.
          final dx = endDx * Curves.easeIn.transform(motionT);
          final dy = endDy * Curves.easeInOutCubic.transform(motionT);

          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: barrierOpacity,
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  // Scaling pivots on the card's own top-right corner
                  // (roughly where it's heading) instead of its center, so
                  // it visibly shrinks *into* that corner rather than just
                  // getting smaller while it slides — that's what actually
                  // reads as "sucked toward a point" instead of "shrinking
                  // in place while drifting".
                  child: Transform(
                    alignment: Alignment.topRight,
                    transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                    child: Opacity(opacity: cardOpacity, child: child),
                  ),
                ),
              ),
            ],
          );
        },
        child: KeyedSubtree(
          key: _cardBoundsKey,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: AppCard(
              padding: EdgeInsets.all(40.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipSmoothRect(
                        radius: squircleRadius(24.r),
                        child: SizedBox(
                          width: 400.w,
                          height: 400.w,
                          child: CachedNetworkImage(
                            imageUrl: '$baseUrl/${widget.product.image}',
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primary,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                widget.product.name.isNotEmpty
                                    ? widget.product.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontFamily: 'Baloo2',
                                  fontSize: 64.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1,
                                  color: primary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Produit vegandex',
                              style: AppTextStyles.baloo22.copyWith(
                                color: primary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              widget.product.name,
                              style: AppTextStyles.baloo22,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              widget.product.brandName,
                              style: AppTextStyles.bodyRegular15.copyWith(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Génial !',
                      backgroundColor: primary,
                      onPressed: _handleClose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
