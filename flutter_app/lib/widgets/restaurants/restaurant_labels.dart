import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/tag_chip.dart';

/// "+0,50 €" style amount.
String _euros(double value) =>
    '${value.abs().toStringAsFixed(2).replaceAll('.', ',')} €';

/// Plant milk surcharge in words, null when unknown.
String? plantMilkSurchargeText(double? surcharge) {
  if (surcharge == null) return null;
  if (surcharge == 0) return 'Lait végétal sans supplément';
  if (surcharge > 0) return 'Lait végétal : +${_euros(surcharge)}';
  return 'Lait végétal moins cher (−${_euros(surcharge)})';
}

/// Closure of the restaurant in words: closed for good, closed now until a
/// date, or an announced closure. Null when nothing to say.
String? closureText(Restaurant restaurant, DateTime now) {
  final date = DateFormat.MMMd('fr_FR');
  switch (restaurant.operatingStatus) {
    case OperatingStatus.permanentlyClosed:
      return 'Fermé définitivement';
    case OperatingStatus.temporarilyClosed:
      final from = restaurant.closedFrom;
      final until = restaurant.closedUntil;
      if (restaurant.isClosedNow) {
        return until != null
            ? 'Fermé jusqu\'au ${date.format(until)}'
            : 'Fermé temporairement';
      }
      if (from != null && from.isAfter(now)) {
        return until != null
            ? 'Fermeture du ${date.format(from)} au ${date.format(until)}'
            : 'Fermeture à partir du ${date.format(from)}';
      }
  }
  return null;
}

/// "100 % végane" (green) or "Options véganes" (yellow) tag.
class VeganStatusChip extends StatelessWidget {
  final bool isFullyVegan;

  const VeganStatusChip({super.key, required this.isFullyVegan});

  @override
  Widget build(BuildContext context) {
    return isFullyVegan
        ? const TagChip(
            label: '100 % végane',
            icon: Icons.eco,
            color: kSemanticSuccess,
            backgroundColor: kPrimaryTag,
          )
        : const TagChip(
            label: 'Options véganes',
            icon: Icons.eco_outlined,
            color: kAccentYellow,
            backgroundColor: kSecondaryTag,
          );
  }
}

/// "Ouvert · ferme à 14:30" / "Fermé · ouvre demain à 12:00", or the
/// closure when the place is closed for a period. Nothing when unknown.
class OpeningStatusLine extends StatelessWidget {
  final Restaurant restaurant;

  const OpeningStatusLine({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final closure = closureText(restaurant, now);
    if (restaurant.isClosedNow && closure != null) {
      return Text(closure,
          style: AppTextStyles.bodyBold13.copyWith(color: kSemanticError));
    }
    // Caterers without storefront: hours are for orders, not a visit
    if (!restaurant.hasStorefront) return const SizedBox.shrink();

    final state = restaurant.openingStateAt(now);
    if (state == null) return const SizedBox.shrink();
    final color = state.isOpen ? kSemanticSuccess : kSemanticError;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: state.isOpen ? 'Ouvert' : 'Fermé',
          style: AppTextStyles.bodyBold13.copyWith(color: color),
        ),
        TextSpan(
          text: ' · ${state.detail}',
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
      ]),
    );
  }
}

/// Grey tag of a kind of place ("Café", "Traiteur"...).
class RestaurantTagChip extends StatelessWidget {
  final String tag;

  const RestaurantTagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: ShapeDecoration(
        color: Colors.grey[100],
        shape: const StadiumBorder(),
      ),
      child: Text(
        RestaurantTags.label(tag),
        style: AppTextStyles.bodyMedium13.copyWith(color: Colors.grey[700]),
      ),
    );
  }
}
