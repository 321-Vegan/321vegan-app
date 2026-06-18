import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/vegan_status.dart';
import 'package:vegan_app/pages/app_pages/helpers/product.helper.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/widgets/scaner/product_info_form_modal.dart';

class NoResultCard extends StatelessWidget {
  /// Called when the user taps the "produit introuvable en magasin" call to
  /// action. The scan page uses this to pause the scanner and open the
  /// "ask in store" flow.
  final VoidCallback? onAskInStore;

  const NoResultCard({super.key, this.onAskInStore});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 1000.h,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 60.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              children: [
                const TextSpan(text: 'Scannez un produit '),
                TextSpan(
                  text: 'alimentaire',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 60.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' pour savoir s\'il est vegan !'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Image.asset(
            'lib/assets/app_icon.png',
            height: 300.h,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 38.sp, color: Colors.grey.shade600),
              children: [
                const TextSpan(text: 'Le scan ne concerne que les produits '),
                TextSpan(
                  text: 'alimentaires',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          SizedBox(height: 28.h),
          // Call to action: ask a store to add a product that's missing there.
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(24.r),
              onTap: onAskInStore,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A722E), Color(0xFF2E9D47)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A722E).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.storefront,
                            color: Colors.white, size: 56.sp),
                      ),
                      SizedBox(width: 24.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Produit préféré introuvable ?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 44.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Baloo',
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Demandez à votre magasin de l\'ajouter',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 36.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward,
                            color: Colors.white, size: 44.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotFoundProductInfoCard extends StatelessWidget {
  final Map<dynamic, dynamic>? productInfo;

  const NotFoundProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 850.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
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
              productInfo?['code'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (() {
                return 'Ce produit a déjà été soumis mais il est introuvable ! Vous pouvez m\'aider en me transmettant des informations sur celui-ci. Merci !';
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
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Introuvable",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NonVeganProductInfoCard extends StatefulWidget {
  final Map<dynamic, dynamic>? productInfo;
  final ConfettiController confettiController;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onScannerStop;
  final VoidCallback? onScannerStart;

  const NonVeganProductInfoCard({
    super.key,
    required this.productInfo,
    required this.confettiController,
    this.onNavigateToProfile,
    this.onScannerStop,
    this.onScannerStart,
  });

  @override
  NonVeganProductInfoCardState createState() => NonVeganProductInfoCardState();
}

class NonVeganProductInfoCardState extends State<NonVeganProductInfoCard> {
  bool _isButtonDisabled = false;

  void resetButton() {
    setState(() {
      _isButtonDisabled = false;
    });
  }

  void _showInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 54.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  const Expanded(
                    child: Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Alimentaires uniquement
              _buildInfoSection(
                icon: Icons.restaurant,
                iconColor: Colors.green.shade700,
                backgroundColor: Colors.green.shade50,
                title: 'Produits alimentaires uniquement',
                description:
                    'Cette application est conçue pour scanner des produits alimentaires. Les autres types de produits ne peuvent pour l\'instant pas être traités correctement.',
              ),

              SizedBox(height: 16.h),

              // Pas de cosmétiques
              _buildInfoSection(
                icon: Icons.block,
                iconColor: Colors.red.shade700,
                backgroundColor: Colors.red.shade50,
                title: 'Pas de produits cosmétiques',
                description:
                    'Les cosmétiques ne sont pas acceptés. Merci de ne pas les envoyer, ils seront automatiquement rejetés. En attendant, vous pouvez vérifier les marques de cosmétiques via l\'onglet de recherche !',
              ),

              SizedBox(height: 16.h),

              // Traitement manuel
              _buildInfoSection(
                icon: Icons.schedule,
                iconColor: Colors.orange.shade700,
                backgroundColor: Colors.orange.shade50,
                title: 'Traitement manuel',
                description:
                    'Chaque produit envoyé est vérifié manuellement avant d\'être ajouté à la base de données. Cela peut prendre quelques jours.',
              ),

              SizedBox(height: 16.h),

              // Bouton de fermeture
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'J\'ai compris',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 160.h),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    // Use the callback if provided, otherwise try to navigate manually
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      // Fallback: show a snackbar message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Veuillez aller dans l\'onglet Profil pour vous connecter.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  List<Widget> _buildLoginPrompt() {
    return [
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_circle,
              size: 80.sp,
              color: Colors.blue.shade700,
            ),
            SizedBox(height: 16.h),
            Text(
              'Connexion requise',
              style: TextStyle(
                fontSize: 60.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Vous avez la possibilité d\'envoyer des produits pour qu\'ils soient ajoutés à la base de données. Mais pour cela, vous devez vous connecter',
              style: TextStyle(
                fontSize: 40.sp,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, color: Colors.white, size: 24),
                    SizedBox(width: 12.w),
                    Text(
                      'Se connecter / S\'inscrire',
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _sendProduct(VeganStatus veganStatus) async {
    if (_isButtonDisabled) return;

    // Stop scanner while modal is open
    widget.onScannerStop?.call();

    try {
      // Show modal to collect additional info
      final result = await ProductInfoFormModal.show(context);
      if (!mounted) return;

      bool success = await ProductHelper.tryAddDocument(
        context,
        widget.productInfo,
        veganStatus,
        productName: result?.productName ?? '',
        brand: result?.brand ?? '',
        photo: result?.photo,
      );
      if (success) {
        setState(() {
          _isButtonDisabled = true;
        });
        widget.confettiController.play();
      }
    } finally {
      // Restart scanner only after the entire flow completes
      widget.onScannerStart?.call();
    }
  }

  List<Widget> _buildLoggedInButtons() {
    return [
      // Side by side buttons for vegan/non-vegan
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isButtonDisabled
                  ? null
                  : () => _sendProduct(VeganStatus.vegan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 60.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "C'est végane",
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton(
              onPressed: _isButtonDisabled
                  ? null
                  : () => _sendProduct(VeganStatus.nonVegan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 60.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "C'est pas végane",
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Center(
        child: SizedBox(
          width: 500.w,
          child: ElevatedButton(
            onPressed: _isButtonDisabled
                ? null
                : () => _sendProduct(VeganStatus.maybeVegan),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 60.sp,
                ),
                SizedBox(width: 20.w),
                Text(
                  'Je ne sais pas',
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildInfoSection({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 60.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 32.sp,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1000.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
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
              widget.productInfo?['name'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "Produit non référencé",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (AuthService.isLoggedIn) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showInfoModal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade200, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                            children: [
                              const TextSpan(
                                  text:
                                      'Merci de n\'envoyer que des produits '),
                              TextSpan(
                                text: 'alimentaires.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const TextSpan(text: ' Pas de '),
                              TextSpan(
                                text: 'cosmétiques',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showInfoModal,
                        icon: Icon(Icons.help_outline,
                            color: Colors.blue.shade700),
                        tooltip: 'Plus d\'infos',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Traitement manuel • Vérification avant ajout",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            SizedBox(height: 40.h),
            // Check if user is logged in
            if (AuthService.isLoggedIn) ..._buildLoggedInButtons(),
            if (!AuthService.isLoggedIn) ..._buildLoginPrompt(),
          ],
        ),
      ),
    );
  }
}

class RejectedProductInfoCard extends StatelessWidget {
  final Map<dynamic, dynamic>? productInfo;

  const RejectedProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    // In the database, the reason why its not vegan is stored in the brand field; separated by '--'
    final reason = productInfo?['problem'];
    final brand = productInfo?['brand'];

    return Container(
      height: 740.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.red,
          width: 3,
        ),
        boxShadow: [
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
              Helper.truncate(
                (productInfo?['name']?.isNotEmpty ?? false)
                    ? productInfo!['name']
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
            Text(
              (() {
                // Check if the brand is not null and is a non-empty string
                if (brand != null && brand is String && brand.isNotEmpty) {
                  // Capitalize the first letter and keep the rest
                  String formattedBrand =
                      '${brand[0].toUpperCase()}${brand.substring(1)}';
                  if (formattedBrand.length > 30) {
                    // Truncate and add ellipsis
                    formattedBrand = '${formattedBrand.substring(0, 30)}...';
                  }
                  return formattedBrand;
                }
                // Default text
                return 'Marque inconnue';
              })(),
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Add a text for the reason
            const SizedBox(height: 16),
            Text(
              "Pas Vegan !",
              style: TextStyle(
                fontSize: 80.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
