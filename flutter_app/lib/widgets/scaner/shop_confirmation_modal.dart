import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../models/product_of_interest.dart';
import '../../services/api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_card.dart';

class ShopConfirmationModal extends StatefulWidget {
  final String shopName;
  final int scanEventId;
  final ProductOfInterest product;
  final List<Map<String, dynamic>> nearbyShops;
  /// The OSM ID of the primary proposed shop, if it hasn't been linked yet.
  /// When present, tapping "Yes" will call confirmShop to create and link it.
  final String? shopOsmId;

  const ShopConfirmationModal({
    super.key,
    required this.shopName,
    required this.scanEventId,
    required this.product,
    this.nearbyShops = const [],
    this.shopOsmId,
  });

  @override
  State<ShopConfirmationModal> createState() => _ShopConfirmationModalState();
}

class _ShopConfirmationModalState extends State<ShopConfirmationModal>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showAlternatives = false;

  final baseUrl = dotenv.env['API_BASE_URL'];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Start animations
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Closes the modal immediately instead of blocking on an in-modal "thank
  // you" animation, then thanks the user via a snackbar on the underlying
  // page — the messenger is captured before popping since this widget's
  // context won't survive the pop.
  void _showThanksAndClose() {
    final messenger = ScaffoldMessenger.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          shape: squircleBorder(radius: 16.r),
          margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          duration: const Duration(seconds: 2),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12.w),
              Text(
                'Merci !',
                style: AppTextStyles.bodyBold15.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _handleNo() async {
    if (widget.nearbyShops.isNotEmpty) {
      // Show alternative shops instead of nullifying
      setState(() {
        _showAlternatives = true;
      });
    } else {
      // No alternatives available - nullify as before
      await ApiService.updateScanEvent(scanEventId: widget.scanEventId);
      _showThanksAndClose();
    }
  }

  Future<void> _handleYes() async {
    // If the shop wasn't linked yet (OSM-only), confirm it now so it gets
    // created in DB and associated with the scan event.
    if (widget.shopOsmId != null) {
      await ApiService.confirmShop(
        scanEventId: widget.scanEventId,
        osmId: widget.shopOsmId!,
      );
    }
    _showThanksAndClose();
  }

  Future<void> _handleSelectShop(Map<String, dynamic> shop) async {
    // OSM-only shops carry an osm_id (confirm-shop creates and links them);
    // shops already in DB carry an id (and may have no osm_id).
    final osmId = shop['osm_id'] as String?;
    final shopId = shop['id'] as int?;

    if (osmId != null) {
      await ApiService.confirmShop(
        scanEventId: widget.scanEventId,
        osmId: osmId,
      );
    } else if (shopId != null) {
      await ApiService.updateScanEvent(
        scanEventId: widget.scanEventId,
        shopId: shopId,
      );
    } else {
      // No usable identifier - clear the shop association instead
      await ApiService.updateScanEvent(scanEventId: widget.scanEventId);
    }
    _showThanksAndClose();
  }

  Future<void> _handleNoneOfThese() async {
    // User says none of the shops match - nullify
    await ApiService.updateScanEvent(scanEventId: widget.scanEventId);
    _showThanksAndClose();
  }

  @override
  Widget build(BuildContext context) {
    final decodedShopName = widget.shopName;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dark overlay
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),

          // Modal content
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: AppCard(
                  padding: EdgeInsets.all(32.w),
                  child: _showAlternatives
                      ? _buildAlternativesContent(primary)
                      : _buildConfirmationContent(decodedShopName, primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent(String decodedShopName, Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipSmoothRect(
              radius: squircleRadius(24.r),
              child: SizedBox(
                width: 200.w,
                height: 200.w,
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

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmation du magasin',
                    style: AppTextStyles.baloo22.copyWith(color: kSemanticSuccess),
                  ),

                  SizedBox(height: 16.h),

                  // Product name highlight

                  Text(
                      widget.product.name,
                      style: AppTextStyles.baloo22,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                
                  SizedBox(height: 16.h),

                  // Question text
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyRegular15.copyWith(
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                            text: 'Avez-vous trouvé ce produit à '),
                        TextSpan(
                          text: decodedShopName,
                          style:
                              AppTextStyles.bodyBold15.copyWith(color: kSemanticSuccess),
                        ),
                        const TextSpan(text: ' ?'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 32.h),

        // Buttons row
        Row(
          children: [
            // No button
            Expanded(
              child: AppButton(
                label: 'Non',
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[700]!,
                borderColor: kBorderDefault,
                onPressed: _handleNo,
              ),
            ),

            SizedBox(width: 16.w),

            // Yes button
            Expanded(
              child: AppButton(
                label: 'Oui',
                backgroundColor: primary,
                onPressed: _handleYes,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlternativesContent(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipSmoothRect(
              radius: squircleRadius(24.r),
              child: SizedBox(
                width: 200.w,
                height: 200.w,
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

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Autres magasins à proximité',
                    style: AppTextStyles.baloo22,
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'Étiez-vous dans l\'un de ces magasins ?',
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 24.h),

        // Shop list
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 600.h),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.nearbyShops.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final shop = widget.nearbyShops[index];
              final name = shop['name'] as String? ?? 'Magasin inconnu';
              final address = shop['address'] as String?;
              final city = shop['city'] as String?;
              final subtitle = [address, city]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(', ');

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleSelectShop(shop),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 20.h,
                    ),
                    shape: squircleBorder(radius: 42.r),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.bodyBold15
                                  .copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: AppTextStyles.bodyRegular13.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 20.h),

        // "None of these" button
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Aucun de ceux-ci',
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey[700]!,
            borderColor: kBorderDefault,
            onPressed: _handleNoneOfThese,
          ),
        ),
      ],
    );
  }
}
