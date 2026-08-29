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

  /// Called the instant the close animation finishes — the card visually
  /// lands in the Vegandex button — so the caller can react (e.g. shake it).
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

  // Measures the card's rendered size so the translate offset compensates
  // for the top-right-anchored scale in build() and lands on the button.
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
    // Motion runs the full duration with sharp acceleration near the end;
    // opacity stays near 1 until the very last moment then drops fast —
    // otherwise the card reads as "dissolving" rather than "sucked in".
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

    // Approximate on-screen position of the Vegandex button (top row,
    // right edge — see scan.dart's _buildVegandexButton).
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

          // The scale pivots on the card's top-right corner, which stays
          // fixed on screen unless translated too — otherwise the shrink
          // point ends up half a card-width past the button.
          final cardBox =
              _cardBoundsKey.currentContext?.findRenderObject() as RenderBox?;
          final cardSize =
              (cardBox != null && cardBox.hasSize) ? cardBox.size : Size.zero;
          final endDx = targetDx - cardSize.width / 2;
          final endDy = targetDy + cardSize.height / 2;
          // Horizontal and vertical motion ease at different rates so the
          // card arcs into the corner instead of sliding on a straight diagonal.
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
                  // Pivots on the card's top-right corner (where it's
                  // heading) so it shrinks *into* that point, not in place.
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
