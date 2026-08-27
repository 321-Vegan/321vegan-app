import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_card.dart';
import '../../../widgets/shared/info_box.dart';

/// Full-screen "Remerciements" page, reached from Paramètres › Communauté —
/// credits the product-validation/brand-contact contributors, the codebase
/// contributors, the illustrators and the UI/UX designer.
class RemerciementsPage extends StatelessWidget {
  const RemerciementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Remerciements', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal, 8.h, AppSpacing.pageHorizontal, 32.h),
            children: [
              const InfoBox(
                icon: Icons.favorite,
                text: '321 Vegan n\'existerait pas sans toutes les personnes '
                    'qui contribuent au projet. Merci à vous !',
              ),
              SizedBox(height: AppSpacing.section),
              const _CreditCard(
                title: 'Communauté',
                description: 'Un immense merci à toutes les personnes qui '
                    'participent à la validation des produits et au contact '
                    'des marques : un travail essentiel et précieux !',
                tagLabel: 'Validation produits & Marques',
                placeholderIcon: Icons.volunteer_activism_outlined,
                linkIcon: Icons.open_in_new,
                linkLabel: 'discord.com',
                imageAsset: 'lib/assets/images/remerciements/discord.png',
                url: 'https://discord.gg/NV67QXS2JF',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Développeur·euses',
                description: 'Merci aussi à toutes celles et ceux qui '
                    'contribuent au code de l\'application, développée en '
                    'open source.',
                tagLabel: 'Code',
                placeholderIcon: Icons.code,
                imageAsset: 'lib/assets/images/remerciements/github.png',
                linkIcon: Icons.open_in_new,
                linkLabel: 'github.com/321-Vegan',
                url: 'https://github.com/321-Vegan',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Noémie Bertosio',
                tagLabel: 'UX/UI Design',
                placeholderIcon: Icons.palette_outlined,
                imageAsset: 'lib/assets/images/remerciements/noemie-bertosio.webp',
                linkIcon: Icons.open_in_new,
                linkLabel: 'noemie-bertosio.com',
                url: 'https://www.noemie-bertosio.com/',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Isabelle Hugues',
                tagLabel: 'Développement',
                placeholderIcon: Icons.code,
                imageAsset: 'lib/assets/images/remerciements/isabelle.webp',
                linkIcon: Icons.open_in_new,
                linkLabel: 'isabelle-hugues.com',
                url: 'https://www.isabelle-hugues.com/',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Annabelle',
                tagLabel: 'Illustrations',
                placeholderIcon: Icons.brush_outlined,
                imageAsset: 'lib/assets/images/remerciements/anabelle.webp',
                linkIconAsset: 'lib/assets/images/icons/instagram.webp',
                linkLabel: 'kodasmarket.art',
                url: 'https://www.instagram.com/kodasmarket.art/',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Vilaine Végane',
                tagLabel: 'Illustrations',
                placeholderIcon: Icons.brush_outlined,
                imageAsset: 'lib/assets/images/remerciements/vilainevegane.webp',
                linkIconAsset: 'lib/assets/images/icons/instagram.webp',
                linkLabel: 'vilainevegane.illustration',
                url: 'https://www.instagram.com/vilainevegane.illustration/',
              ),
              SizedBox(height: AppSpacing.item),
              const _CreditCard(
                title: 'Ancielle',
                tagLabel: 'Illustrations',
                placeholderIcon: Icons.brush_outlined,
                imageAsset: 'lib/assets/images/remerciements/ancielle.webp',
                linkIconAsset: 'lib/assets/images/icons/instagram.webp',
                linkLabel: 'ancielouille',
                url: 'https://www.instagram.com/ancielouille/',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "leading thumbnail + name/description + link + tag" credit row,
/// styled like [PartnersPage]'s partner cards. [imageAsset] is optional —
/// until real portraits/illustrations are added, [placeholderIcon] fills
/// the thumbnail (and stays as the fallback if the asset fails to load).
class _CreditCard extends StatelessWidget {
  final String title;
  final String? description;
  final String tagLabel;
  final IconData placeholderIcon;
  final String? imageAsset;
  final IconData? linkIcon;
  final String? linkIconAsset;

  /// Whether [linkIconAsset] is tinted grey. Some brand marks (Discord,
  /// GitHub) must keep their official color and can't be recolored per
  /// their brand guidelines, so this is false for those.
  final bool tintLinkIconAsset;
  final String? linkLabel;
  final String? url;

  const _CreditCard({
    required this.title,
    this.description,
    required this.tagLabel,
    required this.placeholderIcon,
    this.imageAsset,
    this.linkIcon,
    this.linkIconAsset,
    this.tintLinkIconAsset = true,
    this.linkLabel,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard();
    if (url == null) return card;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: card,
    );
  }

  Widget _buildCard() {
    return AppCard(
      radius: 60.r,
      padding: EdgeInsets.all(45.w),
      child: Row(
        children: [
          ClipSmoothRect(
            radius: squircleRadius(33.r),
            child: Container(
              width: 240.w,
              height: 240.w,
              color: imageAsset == null ? Colors.grey[100] : Colors.white,
              child: imageAsset == null
                  ? Icon(placeholderIcon, size: 64.sp, color: Colors.grey[400])
                  : Image.asset(
                      imageAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        placeholderIcon,
                        size: 64.sp,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          SizedBox(width: 60.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.baloo22,
                ),
                if (description != null) ...[
                  SizedBox(height: 24.h),
                  Text(
                    description!,
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[700], height: 1.4),
                  ),
                ],
                if (linkIcon != null || linkIconAsset != null) ...[
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (linkIconAsset != null)
                        Image.asset(
                          linkIconAsset!,
                          width: 48.sp,
                          height: 48.sp,
                          color: tintLinkIconAsset ? Colors.grey[600] : null,
                          colorBlendMode:
                              tintLinkIconAsset ? BlendMode.srcIn : null,
                        )
                      else
                        Icon(linkIcon, size: 42.sp, color: Colors.grey[600]),
                      if (linkLabel != null) ...[
                        SizedBox(width: 12.w),
                        Flexible(
                          child: Text(
                            linkLabel!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: AppTextStyles.bodyRegular13.copyWith(
                              fontWeight: const FontWeight(500),
                              color: kTextPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                SizedBox(height: 12.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  decoration: ShapeDecoration(
                    color: kAccentYellow.withValues(alpha: 0.15),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    tagLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium13
                        .copyWith(color: kAccentYellow),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
