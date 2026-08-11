import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class PendingProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;

  const PendingProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 750.h,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: squircleBorder(radius: 30),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productInfo.name.isNotEmpty ? productInfo.name : 'Nom inconnu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              (() {
                return 'Certains ingrédients de ce produit ne sont pas clairs. Nous allons contacter la marque. Si vous avez des informations, contactez-moi !';
              })(),
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: ShapeDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                shape: squircleBorder(radius: 20),
              ),
              child: const Text(
                "En vérification",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlreadyScannedProductInfoCard extends StatelessWidget {
  const AlreadyScannedProductInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600.h,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: squircleBorder(radius: 30),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (() {
                return 'Vous avez déjà soumis ce produit. Nous allons vérifier et l\'ajouter à la base de données. Merci !';
              })(),
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: ShapeDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: squircleBorder(radius: 20),
              ),
              child: const Text(
                "En attente",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
