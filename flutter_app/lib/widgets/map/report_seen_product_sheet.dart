import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/models/shops/shop.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

/// Asks to confirm that [product] was seen at [shop] without scanning it,
/// then sends a "found" report. Unlike a scan, the report doesn't add the
/// product to the Vegandex and raises its presence score less.
///
/// [onSent] runs as soon as the report is sent, while the thank-you message
/// is still showing, so the shop's product list can refresh underneath.
Future<void> showReportSeenProductSheet(
  BuildContext context, {
  required ProductOfInterest product,
  required Shop shop,
  required VoidCallback onSent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSeenProductSheet(
      product: product,
      shop: shop,
      onSent: onSent,
    ),
  );
}

class _ReportSeenProductSheet extends StatefulWidget {
  final ProductOfInterest product;
  final Shop shop;
  final VoidCallback onSent;

  const _ReportSeenProductSheet({
    required this.product,
    required this.shop,
    required this.onSent,
  });

  @override
  State<_ReportSeenProductSheet> createState() =>
      _ReportSeenProductSheetState();
}

class _ReportSeenProductSheetState extends State<_ReportSeenProductSheet> {
  bool _isSending = false;
  bool _sent = false;
  bool _failed = false;

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _failed = false;
    });
    final success = await ApiService.postProductFoundReport(
      ean: widget.product.ean,
      shopId: widget.shop.id,
    );
    if (success) {
      await PreferencesHelper.saveProductFoundReport(
          widget.product.ean, widget.shop.id);
      widget.onSent();
    }
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = success;
      _failed = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return BottomSheetShell(
      padding: EdgeInsets.fromLTRB(
          51.w, 12.h, 51.w, MediaQuery.of(context).padding.bottom + 60.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _sent ? _buildSent(primary) : _buildConfirm(primary),
      ),
    );
  }

  List<Widget> _buildConfirm(Color primary) {
    final product = widget.product;
    final subtitle = [product.name, product.brandName]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return [
      _buildProductImage(),
      SizedBox(height: 36.h),
      Text(
        'Vous avez vu ce produit ici ?',
        style: AppTextStyles.baloo22,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 12.h),
      Text(
        subtitle,
        style: AppTextStyles.bodyMedium15,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 6.h),
      Text(
        'chez ${widget.shop.name}',
        style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 48.h),
      const InfoBox(
        text: "Sans scan, votre signalement compte moins qu'un scan dans la "
            "probabilité de présence, et le produit n'est pas ajouté à votre "
            'Vegandex.',
      ),
      if (_failed) ...[
        SizedBox(height: 30.h),
        Text(
          "L'envoi a échoué. Vérifiez votre connexion et réessayez !",
          style: AppTextStyles.bodyMedium13.copyWith(color: kSemanticError),
          textAlign: TextAlign.center,
        ),
      ],
      SizedBox(height: 48.h),
      SizedBox(
        width: double.infinity,
        child: AppButton(
          label: "Oui, je l'ai vu ici",
          icon: Icons.visibility_outlined,
          backgroundColor: primary,
          isLoading: _isSending,
          onPressed: _isSending ? null : _send,
        ),
      ),
      SizedBox(height: 8.h),
      TextButton(
        onPressed: _isSending ? null : () => Navigator.of(context).pop(),
        child: Text(
          'Annuler',
          style: AppTextStyles.bodyMedium15.copyWith(color: Colors.grey[600]),
        ),
      ),
    ];
  }

  List<Widget> _buildSent(Color primary) {
    return [
      Icon(Icons.check_circle, size: 160.sp, color: kSemanticSuccess),
      SizedBox(height: 36.h),
      Text(
        'Merci !',
        style: AppTextStyles.baloo22,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 18.h),
      Text(
        'Le produit apparaît maintenant dans la liste de ce magasin, marqué '
        "« Vu sans scan ». Scannez-le la prochaine fois pour l'ajouter à "
        'votre Vegandex.',
        style: AppTextStyles.bodyRegular15
            .copyWith(color: Colors.grey[600], height: 1.4),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 60.h),
      SizedBox(
        width: double.infinity,
        child: AppButton(
          label: 'Fermer',
          backgroundColor: primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ];
  }

  Widget _buildProductImage() {
    final image = widget.product.image;
    final placeholder = Container(
      color: Colors.grey[100],
      child: Icon(Icons.image, color: Colors.grey[400]),
    );
    return ClipSmoothRect(
      radius: squircleRadius(42.r),
      child: SizedBox(
        width: 300.w,
        height: 300.w,
        child: image.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: '$_baseUrl/$image',
                fit: BoxFit.contain,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}
