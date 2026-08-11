import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/scaner/info_modal.dart';

class VeganProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;
  final bool showBoycott;
  final Function(bool)? onBoycottToggleChanged;

  const VeganProductInfoCard({
    super.key,
    required this.productInfo,
    this.showBoycott = true,
    this.onBoycottToggleChanged,
  });

  BoycottMatch? getBoycottMatch() {
    final brand = productInfo.brand;
    if (brand.isNotEmpty) {
      return BoycottData.findBrand(brand);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final BoycottMatch? boycottMatch = getBoycottMatch();
    final bool isBoycotted = boycottMatch != null;

    return Container(
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: squircleBorder(
          radius: 30,
          side: const BorderSide(color: Colors.green, width: 3),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Helper.truncate(
                productInfo.name.isNotEmpty
                    ? productInfo.name
                    : 'Unnamed Product',
                45,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (() {
                final brand = productInfo.brand;
                if (brand.isNotEmpty) {
                  String formattedBrand =
                      '${brand[0].toUpperCase()}${brand.substring(1)}';
                  if (formattedBrand.length > 30) {
                    formattedBrand = '${formattedBrand.substring(0, 30)}...';
                  }
                  return formattedBrand;
                }
                return 'Marque inconnue';
              })(),
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!productInfo.biodynamic)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(productInfo.name),
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.8, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Text(
                          'Vegan !',
                          style: TextStyle(
                            fontSize: 80.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
                if (isBoycotted && showBoycott) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => InfoModal(
                          description:
                              "Les produits notés 'À éviter' sont des produits de marques qui ont des actions néfastes pour l'environnement, la santé, les droits des animaux ou les droits humains. Nous vous encourageons à boycotter ces marques pour soutenir des pratiques éthiques et responsables.",
                          boycottMatch: boycottMatch,
                          showBoycottToggle: true,
                          initialBoycottValue: showBoycott,
                          onBoycottToggleChanged: onBoycottToggleChanged,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade500,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: squircleBorder(radius: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'À éviter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 60.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ],
                if (!isBoycotted && productInfo.biodynamic) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const InfoModal(
                          description:
                              "La biodynamie est une méthode agricole qui utilise des préparations d'origine animale, telles que des cornes de vache ou des organes d'animaux, dans ses pratiques de culture. Cette approche est issue de l'anthroposophie, un courant ésotérique aux dérives parfois considérées comme sectaires. En raison de l'utilisation d'éléments animaux et de son ancrage idéologique, nous ne considérons pas les produits issus de la biodynamie comme compatibles avec les principes du véganisme.",
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade500,
                      shape: squircleBorder(radius: 12),
                    ),
                    child:
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Text(
                        '🚫 Biodynamie',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 60.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      ]
                    )
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
