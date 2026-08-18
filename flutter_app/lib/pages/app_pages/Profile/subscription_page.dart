import 'dart:io';
import 'dart:ui';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import '../../../services/subscription_service.dart';
import '../../../services/auth_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../widgets/auth/forgot_password_form.dart';
import '../../../widgets/auth/login_form.dart';
import '../../../widgets/auth/register_form.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/subscription_goal_widget.dart';

class SubscriptionPage extends StatefulWidget {
  final String? title;

  const SubscriptionPage({super.key, this.title});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isYearly = false;
  int _selectedTier = 2; // 1, 2, or 3 — default to middle tier
  String? _errorMessage;

  String? get _selectedProductId {
    if (_isYearly) {
      switch (_selectedTier) {
        case 1:
          return SubscriptionService.yearlyId;
        case 2:
          return SubscriptionService.tier1YearlyId;
        case 3:
          return SubscriptionService.tier2YearlyId;
      }
    } else {
      switch (_selectedTier) {
        case 1:
          return SubscriptionService.monthlyId;
        case 2:
          return SubscriptionService.tier1MonthlyId;
        case 3:
          return SubscriptionService.tier2MonthlyId;
      }
    }
    return null;
  }

  /// Reference price for a yearly plan (its monthly price × 12), to show struck
  /// through next to the discounted yearly price. Matches the displayed
  /// price exactly. Returns null if it can't be computed or there's no saving.
  String? _yearlyReferencePrice(String monthlyId, String yearlyId) {
    final monthly = SubscriptionService.getProduct(monthlyId);
    final yearly = SubscriptionService.getProduct(yearlyId);
    if (monthly == null || yearly == null || monthly.rawPrice <= 0) return null;
    final reference = monthly.rawPrice * 12;
    if (reference <= yearly.rawPrice) return null;

    final priceStr = monthly.price;
    final usesComma = RegExp(r',\d{1,2}(?:\D|$)').hasMatch(priceStr);
    final number =
        reference.toStringAsFixed(2).replaceAll('.', usesComma ? ',' : '.');
    final symbol = priceStr.replaceAll(RegExp(r'[\d.,\s ]'), '').trim();
    if (symbol.isEmpty) return number;
    return priceStr.trimLeft().startsWith(symbol)
        ? '$symbol$number'
        : '$number $symbol';
  }

  @override
  void initState() {
    super.initState();
    SubscriptionService.onSubscriptionChanged = _onSubscriptionChanged;
  }

  @override
  void dispose() {
    SubscriptionService.onSubscriptionChanged = null;
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (mounted) {
      setState(() {});
      if (SubscriptionService.isSubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Merci pour votre soutien !',
              style: TextStyle(fontSize: 44.sp, fontFamily: 'Baloo'),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _purchase() async {
    if (!AuthService.isLoggedIn) {
      setState(() {
        _errorMessage = 'Vous devez être connecté pour vous abonner.';
      });
      return;
    }

    if (_selectedProductId == null) return;

    final product = SubscriptionService.products
        .where((p) => p.id == _selectedProductId)
        .firstOrNull;

    if (product == null) {
      setState(() {
        _errorMessage = 'Produit non disponible. Réessayez plus tard.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SubscriptionService.buyProduct(product);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'achat. Réessayez plus tard. $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      await SubscriptionService.restorePurchases();
      // Give a moment for the purchase stream to process
      await Future.delayed(const Duration(seconds: 2));
      await SubscriptionService.checkSubscriptionStatus();

      if (mounted) {
        if (SubscriptionService.isSubscribed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Abonnement restauré avec succès !',
                style: TextStyle(fontSize: 44.sp, fontFamily: 'Baloo'),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } else {
          setState(() {
            _errorMessage =
                'Aucun abonnement trouvé. N\'hésitez pas à nous contacter si vous pensez que c\'est une erreur.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la restauration.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = SubscriptionService.isSubscribed;
    final subscription = SubscriptionService.currentSubscription;
    final isBypass = AuthService.currentUser?.subscriptionBypass ?? false;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: primaryColor,
      // SizedBox.expand pins the Stack to the exact viewport size instead of
      // letting it size itself off the scrollable child, so the auth overlay
      // below — a Positioned.fill sibling — reliably covers the whole
      // screen instead of stopping short at the bottom.
      body: SizedBox.expand(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal: 40.w, vertical: 16.h),
                      child: Column(
                        children: [
                          // Close button, top-left like the mockup.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close,
                                  color: Colors.white, size: 64.sp),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          // Already subscribed: current plan card, thank-you
                          // header, benefits recap, community goal. The
                          // manage-subscription button lives outside this
                          // scroll view, pinned to the bottom of the screen.
                          if (isSubscribed) ...[
                            if (subscription != null) ...[
                              _buildCurrentPlanCard(subscription),
                              SizedBox(height: 56.h),
                            ],
                            _buildSubscribedHeader(),
                            SizedBox(height: 56.h),
                            _buildBenefits(primaryColor),
                            SizedBox(height: 32.h),
                            const SubscriptionGoalWidget(),
                            SizedBox(height: 32.h),
                          ],

                          // Header illustration
                          if (!isSubscribed) ...[
                            _buildHeader(primaryColor),
                            SizedBox(height: 32.h),
                            const SubscriptionGoalWidget(),
                            SizedBox(height: 32.h),

                            // Benefits list
                            _buildBenefits(primaryColor),
                            SizedBox(height: 32.h),

                            // Plan cards
                            if (SubscriptionService.products.isNotEmpty) ...[
                              _buildPlanCards(primaryColor),
                              SizedBox(height: 8.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                child: Text(
                                  'Tous les paliers débloquent les mêmes avantages. Choisissez simplement selon vos moyens !',
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 24.h),

                              // Error message
                              if (_errorMessage != null) ...[
                                Padding(
                                  padding: EdgeInsets.only(bottom: 16.h),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 38.sp,
                                      color: const Color(0xFFFFC9C9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],

                              // Purchase button
                              _buildPurchaseButton(primaryColor),
                              SizedBox(height: 20.h),

                              // Restore button
                              _buildRestoreButton(),
                              SizedBox(height: 24.h),

                              // Legal links
                              _buildLegalLinks(),
                            ] else ...[
                              _buildProductsUnavailable(),
                            ],

                            SizedBox(height: 32.h),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bypass users have no store subscription to manage.
                  if (isSubscribed && !isBypass)
                    Padding(
                      padding: EdgeInsets.fromLTRB(40.w, 16.h, 40.w, 24.h),
                      child: _buildManageSubscriptionButton(),
                    ),
                ],
              ),
            ),
            // Auth overlay when not logged in
            if (!AuthService.isLoggedIn) _buildAuthOverlay(primaryColor),
          ],
        ),
      ),
    );
  }

  /// Tier metadata for a store product id (title, subtitle, illustration).
  ({String title, String subtitle, String image}) _tierInfo(String productId) {
    if (productId.contains('tier2')) {
      return (
        title: 'Arbre',
        subtitle: 'Pionnier du changement !',
        image: 'lib/assets/images/buy-premium/tree.webp',
      );
    }
    if (productId.contains('tier1')) {
      return (
        title: 'Fleur',
        subtitle: 'Un soutien énorme !',
        image: 'lib/assets/images/buy-premium/flower.webp',
      );
    }
    return (
      title: 'Graine',
      subtitle: 'Un bon coup de pouce !',
      image: 'lib/assets/images/buy-premium/seed.webp',
    );
  }

  /// The subscriber's current plan, shown highlighted at the top of the
  /// already-subscribed view.
  Widget _buildCurrentPlanCard(subscription) {
    final String productId = subscription.productId;
    final info = _tierInfo(productId);
    return _planCard(
      title: info.title,
      subtitle: info.subtitle,
      image: info.image,
      price: SubscriptionService.getProduct(productId)?.price,
      periodSuffix: productId.contains('yearly') ? '/an' : '/mois',
      highlighted: true,
    );
  }

  Widget _buildSubscribedHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Vous êtes Premium !',
                style: AppTextStyles.baloo36.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 16.w),
            Image.asset(
              'lib/assets/images/icons/crown-line.webp',
              width: 72.sp,
              height: 72.sp,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          'Grâce à vous, ce projet peut continuer !',
          style: TextStyle(
            fontSize: 42.sp,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.title ?? 'Passez Premium !',
                style: TextStyle(
                  fontSize: 84.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Baloo2',
                  height: 1.0,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 16.w),
            Image.asset(
              'lib/assets/images/icons/crown-line.webp',
              width: 72.sp,
              height: 72.sp,
              color: kAccentYellow,
              colorBlendMode: BlendMode.srcIn,
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          'Accédez à de nouvelles fonctionnalités\net faites grandir le projet !',
          style: TextStyle(
            fontSize: 42.sp,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBenefits(Color primaryColor) {
    const benefits = [
      'Map des produits autour de vous',
      'NutriScore et GreenScore illimités',
      'Tous les thèmes débloqués',
      'Badge soutien sur votre profil',
      'Soutien pour faire vivre l\'app',
    ];

    return Column(
      children: [
        for (final benefit in benefits)
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Row(
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 44.sp, color: primaryColor),
                ),
                SizedBox(width: 24.w),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBillingToggle(Color primaryColor) {
    Widget option(String label, bool yearly) {
      final selected = _isYearly == yearly;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isYearly = yearly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: ShapeDecoration(
              color: selected ? Colors.white : Colors.transparent,
              shape: squircleBorder(radius: 30.r),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 42.sp,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        shape: squircleBorder(radius: 34.r),
      ),
      child: Row(
        children: [
          option('Par mois', false),
          option('Par an', true),
        ],
      ),
    );
  }

  Widget _buildPlanCards(Color primaryColor) {
    final tiers = [
      (
        tier: 1,
        title: 'Graine',
        subtitle: 'Un bon coup de pouce !',
        image: 'lib/assets/images/buy-premium/seed.webp',
        monthlyId: SubscriptionService.monthlyId,
        yearlyId: SubscriptionService.yearlyId,
        isPopular: false,
      ),
      (
        tier: 2,
        title: 'Fleur',
        subtitle: 'Un soutien énorme !',
        image: 'lib/assets/images/buy-premium/flower.webp',
        monthlyId: SubscriptionService.tier1MonthlyId,
        yearlyId: SubscriptionService.tier1YearlyId,
        isPopular: true,
      ),
      (
        tier: 3,
        title: 'Arbre',
        subtitle: 'Pionnier du changement !',
        image: 'lib/assets/images/buy-premium/tree.webp',
        monthlyId: SubscriptionService.tier2MonthlyId,
        yearlyId: SubscriptionService.tier2YearlyId,
        isPopular: false,
      ),
    ];

    return Column(
      children: [
        _buildBillingToggle(primaryColor),
        SizedBox(height: 32.h),
        ...tiers.map((t) {
          final productId = _isYearly ? t.yearlyId : t.monthlyId;
          final product = SubscriptionService.getProduct(productId);

          return Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: _buildTierCard(
              tier: t.tier,
              title: t.title,
              subtitle: t.subtitle,
              image: t.image,
              price: product?.price,
              isPopular: t.isPopular,
              referencePrice: _isYearly
                  ? _yearlyReferencePrice(t.monthlyId, t.yearlyId)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  /// Shared plan-card body: darker overlay card on the green page;
  /// [highlighted] lightens it up with a white outline (selected tier /
  /// current plan).
  Widget _planCard({
    required String title,
    required String subtitle,
    required String image,
    required String? price,
    required String periodSuffix,
    required bool highlighted,
    String? referencePrice,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 45.h),
      decoration: ShapeDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.15),
        shape: squircleBorder(
          radius: 72.r,
          side: BorderSide(
            color: highlighted ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            height: 120.w,
            child: Image.asset(
              image,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.eco,
                size: 60.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          SizedBox(width: 30.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 54.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Baloo2',
                    height: 1.1,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 36.sp,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (referencePrice != null)
                Text(
                  referencePrice,
                  style: TextStyle(
                    fontSize: 34.sp,
                    color: Colors.white.withValues(alpha: 0.6),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              Text(
                price ?? '...',
                style: TextStyle(
                  fontSize: 56.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Baloo2',
                  height: 1.1,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              Text(
                periodSuffix,
                style: TextStyle(
                  fontSize: 34.sp,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required int tier,
    required String title,
    required String subtitle,
    required String image,
    required String? price,
    required bool isPopular,
    String? referencePrice,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = tier),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _planCard(
            title: title,
            subtitle: subtitle,
            image: image,
            price: price,
            periodSuffix: _isYearly ? '/an' : '/mois',
            highlighted: _selectedTier == tier,
            referencePrice: referencePrice,
          ),
          // "Populaire" badge (pale yellow tag, like the mockup)
          if (isPopular)
            Positioned(
              top: -16.h,
              right: 40.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                decoration: ShapeDecoration(
                  color: kSecondaryTag,
                  shape: squircleBorder(radius: 20),
                ),
                child: Text(
                  'Populaire',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD69A08),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: 'S\'abonner',
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
        isLoading: _isLoading,
        onPressed: _purchase,
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _isRestoring ? null : _restore,
      child: _isRestoring
          ? SizedBox(
              height: 40.sp,
              width: 40.sp,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            )
          : Text(
              'J\'ai déjà un abonnement - Restaurer mes achats',
              style: TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
    );
  }

  Widget _buildLegalLinks() {
    const legalUrl =
        'https://docs.google.com/document/d/15Crd8NB5C5OwEy5KNz_HXwFPVMoSWAVO98a2PCfRl38/edit?usp=sharing';

    return Column(
      children: [
        Text(
          'L\'abonnement se renouvelle automatiquement sauf annulation au moins 24h avant la fin de la période en cours.',
          style: TextStyle(
            fontSize: 38.sp,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(legalUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(
            'Conditions d\'utilisation & Politique de confidentialité',
            style: TextStyle(
              fontSize: 40.sp,
              color: Colors.white,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsUnavailable() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: ShapeDecoration(
        color: Colors.orange[50],
        shape: squircleBorder(radius: 16.r),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 80.sp),
          SizedBox(height: 12.h),
          Text(
            'Abonnements non disponibles',
            style: TextStyle(
              fontSize: 44.sp,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Les abonnements ne sont pas disponibles pour le moment. Veuillez réessayer plus tard.',
            style: TextStyle(
              fontSize: 38.sp,
              color: Colors.orange[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Opens the platform's subscription management page (the only way to
  /// change or cancel an in-app subscription).
  Widget _buildManageSubscriptionButton() {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: 'Modifier mon abonnement',
        backgroundColor: kAccentYellow,
        onPressed: () async {
          final Uri url;
          if (Platform.isIOS) {
            url = Uri.parse('https://apps.apple.com/account/subscriptions');
          } else {
            url = Uri.parse(
                'https://play.google.com/store/account/subscriptions');
          }
          await launchUrl(url, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }

  Widget _buildAuthOverlay(Color primaryColor) {
    // Frosted backdrop over the still-visible subscription page. The
    // enclosing Stack is now pinned to the exact viewport via
    // SizedBox.expand in build(), so this Positioned.fill reliably covers
    // the whole screen instead of stopping short at the bottom.
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close,
                          color: Colors.grey[900], size: 64.sp),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'lib/assets/images/buy-premium/pineapple.webp',
                            fit: BoxFit.contain,
                            height: 200.h,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              padding: EdgeInsets.all(24.w),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                size: 120.sp,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Connectez-vous pour soutenir 321 Vegan',
                            style: TextStyle(
                              fontSize: 52.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Créez un compte ou connectez-vous pour vous abonner et débloquer tous les thèmes.',
                            style: TextStyle(
                              fontSize: 40.sp,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showAuthSheet(showRegister: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                shape: squircleBorder(radius: 16.r),
                                elevation: 0,
                              ),
                              child: Text(
                                'Créer un compte',
                                style: TextStyle(
                                  fontSize: 46.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showAuthSheet(showRegister: false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side:
                                    BorderSide(color: primaryColor, width: 1.5),
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                shape: squircleBorder(radius: 16.r),
                              ),
                              child: Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 46.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _showAuthSheet({required bool showRegister}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ClipSmoothRect(
          radius: SmoothBorderRadius.only(
            topLeft: SmoothRadius(
                cornerRadius: 28.r, cornerSmoothing: kCornerSmoothing),
            topRight: SmoothRadius(
                cornerRadius: 28.r, cornerSmoothing: kCornerSmoothing),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(28.w),
              child: _AuthSheetContent(
                initialShowRegister: showRegister,
                onSuccess: () {
                  Navigator.of(context).pop();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthSheetContent extends StatefulWidget {
  final bool initialShowRegister;
  final VoidCallback onSuccess;

  const _AuthSheetContent({
    required this.initialShowRegister,
    required this.onSuccess,
  });

  @override
  State<_AuthSheetContent> createState() => _AuthSheetContentState();
}

enum _AuthView { register, login, forgotPassword }

class _AuthSheetContentState extends State<_AuthSheetContent> {
  late _AuthView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.initialShowRegister ? _AuthView.register : _AuthView.login;
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _AuthView.register:
        return RegisterForm(
          onRegisterSuccess: widget.onSuccess,
          onSwitchToLogin: () => setState(() => _view = _AuthView.login),
        );
      case _AuthView.login:
        return LoginForm(
          onLoginSuccess: widget.onSuccess,
          onSwitchToRegister: () => setState(() => _view = _AuthView.register),
          onSwitchToForgotPassword: () =>
              setState(() => _view = _AuthView.forgotPassword),
        );
      case _AuthView.forgotPassword:
        return ForgotPasswordForm(
          onBackToLogin: () => setState(() => _view = _AuthView.login),
        );
    }
  }
}
