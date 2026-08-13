import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

class SocialFeedbackButtons extends StatelessWidget {
  final bool showCard;

  const SocialFeedbackButtons({
    super.key,
    this.showCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCard) SizedBox(height: 24.h),

        // Instagram button
        ElevatedButton(
          onPressed: () => _openInstagram(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 16.h,
            ),
            shape: squircleBorder(
              radius: 12.r,
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'lib/assets/logo_instagram.png',
                width: 60.w,
                height: 60.w,
              ),
              SizedBox(width: 16.w),
              Flexible(
                child: Text(
                  'Suivez-nous sur Instagram',
                  style: TextStyle(
                    fontSize: 44.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // Rate app button
        ElevatedButton(
          onPressed: () => _rateApp(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 16.h,
            ),
            shape: squircleBorder(radius: 12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 60.sp),
              SizedBox(width: 16.w),
              Flexible(
                child: Text(
                  'Notez l\'application',
                  style: TextStyle(
                    fontSize: 44.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (showCard) {
      return _buildCard(context, child: content);
    }
    return content;
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(28.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 28.r,
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  static Future<void> _openInstagram(BuildContext context) async {
    final url = Uri.parse('https://www.instagram.com/321vegan.app/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Instagram'),
            backgroundColor: kSemanticError,
          ),
        );
      }
    }
  }

  static Future<void> _rateApp(BuildContext context) async {
    try {
      final inAppReview = InAppReview.instance;

      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        // Fallback: open the store page directly
        Uri? url;

        if (Platform.isIOS) {
          url =
              Uri.parse('https://apps.apple.com/fr/app/321-vegan/id6736880006');
        } else if (Platform.isAndroid) {
          url = Uri.parse(
              'https://play.google.com/store/apps/details?id=com.app321vegan.veganapp');
        }

        if (url != null && await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'ouvrir le store'),
                backgroundColor: kSemanticError,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le store'),
            backgroundColor: kSemanticError,
          ),
        );
      }
    }
  }
}
