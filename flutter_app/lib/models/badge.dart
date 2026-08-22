class Badge {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final BadgeType type;
  final int requirement;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.type,
    required this.requirement,
  });

  // Check if the badge is unlocked based on user data
  bool isUnlocked({
    required int productsSent,
    required DateTime? veganSince,
    required int supporterLevel,
    required int errorSolved,
  }) {
    switch (type) {
      case BadgeType.productsSent:
        return productsSent >= requirement;
      case BadgeType.veganYears:
        if (veganSince == null) return false;
        final years = DateTime.now().difference(veganSince).inDays ~/ 365;
        return years >= requirement;
      case BadgeType.supporter:
        return supporterLevel >= requirement;
      case BadgeType.errorReport:
        return errorSolved >= requirement;
    }
  }

  /// Progress toward unlocking this badge, from 0.0 to 1.0
  double getProgress({
    required int productsSent,
    required DateTime? veganSince,
    required int supporterLevel,
    required int errorSolved,
  }) {
    double ratio;
    switch (type) {
      case BadgeType.productsSent:
        ratio = productsSent / requirement;
        break;
      case BadgeType.veganYears:
        if (veganSince == null) return 0.0;
        final days = DateTime.now().difference(veganSince).inDays;
        ratio = days / (requirement * 365);
        break;
      case BadgeType.supporter:
        ratio = supporterLevel / requirement;
        break;
      case BadgeType.errorReport:
        ratio = errorSolved / requirement;
        break;
    }
    return ratio.clamp(0.0, 1.0);
  }

  /// Short progress label like "37 / 50", or null for badge types
  /// where a counter doesn't make sense (e.g. supporter)
  String? getProgressText({
    required int productsSent,
    required DateTime? veganSince,
    required int supporterLevel,
    required int errorSolved,
  }) {
    switch (type) {
      case BadgeType.productsSent:
        return '$productsSent / $requirement';
      case BadgeType.veganYears:
        if (veganSince == null) return null;
        final years = DateTime.now().difference(veganSince).inDays / 365;
        final current = years >= requirement
            ? '$requirement'
            : years.toStringAsFixed(1).replaceAll('.', ',');
        return '$current / $requirement an${requirement > 1 ? 's' : ''}';
      case BadgeType.supporter:
        return null;
      case BadgeType.errorReport:
        return '$errorSolved / $requirement';
    }
  }

  String getRequirementText() {
    switch (type) {
      case BadgeType.productsSent:
        if (requirement == 1) {
          return 'Envoyer votre premier produit';
        }
        return 'Envoyer $requirement produits';
      case BadgeType.veganYears:
        if (requirement == 1) {
          return 'Être vegan depuis 1 an';
        }
        return 'Être vegan depuis $requirement ans';
      case BadgeType.supporter:
        if (requirement == 1) {
          return 'Soutenir le projet';
        }
        return 'Soutien de niveau $requirement';
      case BadgeType.errorReport:
        if (requirement == 1) {
          return 'Signaler une erreur';
        }
        return 'Signaler $requirement erreurs';
    }
  }
}

enum BadgeType {
  productsSent,
  veganYears,
  supporter,
  errorReport,
}

// Predefined badges
class Badges {
  // Using partner logos as temporary badge icons
  static const List<Badge> all = [
    // Supporter badges
    Badge(
      id: 'supporter_1',
      name: 'Soutien',
      description: 'Soutenir le projet d\'une façon ou d\'une autre',
      iconPath: 'lib/assets/badges/soutien.webp',
      type: BadgeType.supporter,
      requirement: 1,
    ),
    // Vegan years badges
    Badge(
      id: 'vegan_1_year',
      name: '1 an',
      description: 'Vegan depuis 1 an',
      iconPath: 'lib/assets/badges/1an.webp',
      type: BadgeType.veganYears,
      requirement: 1,
    ),
    Badge(
      id: 'vegan_2_years',
      name: '2 ans',
      description: 'Vegan depuis 2 ans',
      iconPath: 'lib/assets/badges/2ans.webp',
      type: BadgeType.veganYears,
      requirement: 2,
    ),
    Badge(
      id: 'vegan_5_years',
      name: '5 ans',
      description: 'Vegan depuis 5 ans',
      iconPath: 'lib/assets/badges/5ans.webp',
      type: BadgeType.veganYears,
      requirement: 5,
    ),
    Badge(
      id: 'vegan_10_years',
      name: '10 ans',
      description: 'Vegan depuis 10 ans',
      iconPath: 'lib/assets/badges/10ans.webp',
      type: BadgeType.veganYears,
      requirement: 10,
    ),

    // Products sent badges
    Badge(
      id: 'first_product',
      name: 'Premier pas',
      description: 'Premier produit envoyé',
      iconPath: 'lib/assets/badges/1product.webp',
      type: BadgeType.productsSent,
      requirement: 1,
    ),
    Badge(
      id: 'products_10',
      name: 'Débutant·e',
      description: '10 produits envoyés',
      iconPath: 'lib/assets/badges/10products.webp',
      type: BadgeType.productsSent,
      requirement: 10,
    ),
    Badge(
      id: 'products_50',
      name: 'Actif·ve',
      description: '50 produits envoyés',
      iconPath: 'lib/assets/badges/50products.webp',
      type: BadgeType.productsSent,
      requirement: 50,
    ),
    Badge(
      id: 'products_100',
      name: 'Expert·e',
      description: '100 produits envoyés',
      iconPath: 'lib/assets/badges/100products.webp',
      type: BadgeType.productsSent,
      requirement: 100,
    ),
    Badge(
      id: 'products_500',
      name: 'Légende',
      description: '500 produits envoyés',
      iconPath: 'lib/assets/badges/500products.webp',
      type: BadgeType.productsSent,
      requirement: 500,
    ),

    // Error report badges
    Badge(
      id: 'error_report_1',
      name: 'Sherlock',
      description: 'Une erreur ou info envoyée !',
      iconPath: 'lib/assets/badges/sherlock.webp',
      type: BadgeType.errorReport,
      requirement: 1,
    )
  ];
}
