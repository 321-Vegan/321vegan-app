import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';

const _objectsBaseUrl = 'https://321vegan-objects.s3.sbg.io.cloud.ovh.net/';

/// Bottom sheet showing the photo of a brand's reply about a product.
Future<void> showBrandAnswerDialog(BuildContext context, String brandAnswer) {
  final url = '$_objectsBaseUrl$brandAnswer';
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Réponse de la marque', style: AppTextStyles.baloo22),
          SizedBox(height: 12.h),
          Text(
            "Quand nous avons un doute sur un ingrédient ou un processus potentiellement pas végane, nous contactons la "
            "marque pour en avoir le cœur net. Voici la réponse pour ce produit.",
            style:
                AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
          ),
          SizedBox(height: 32.h),
          Flexible(
            child: GestureDetector(
              onTap: () => _showFullScreen(context, url),
              child: ClipSmoothRect(
                radius: squircleRadius(24.r),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CachedNetworkImage(
                      imageUrl: url,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Padding(
                        padding: EdgeInsets.all(64.w),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Padding(
                        padding: EdgeInsets.all(64.w),
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey[400], size: 60),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.zoom_in,
                            color: Colors.white, size: 56.w),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showFullScreen(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(routeContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
