import 'package:flutter/material.dart';

/// Fixed brand colors from the Figma redesign that live outside the
/// seasonal-theme system (the seasonal themes only swap the primary
/// green and the page background).
///
/// "Color/Secondary/Default" in Figma — yellow accent used for secondary
/// call-to-action buttons (B12 intake, "Voir plus" on promos,
/// "Découvrir les offres", account deletion) and tag/banner borders.
const Color kAccentYellow = Color(0xFFF5BC28);

/// "Color/Secondary/Tag" in Figma — pale yellow background for tags
/// (code pills) and the B12 reminder banner.
const Color kSecondaryTag = Color(0xFFFFF8E4);

/// "Color/Primary/Tag" in Figma — pale green background for the selected
/// state of category chips (product search page).
const Color kPrimaryTag = Color(0xFFDCF0EA);

/// Default page background gradient ("Background/Shade" in Figma).
/// TODO: fold into the seasonal-theme system when seasonal backgrounds
/// are redesigned ?
const Color kBackgroundGradientTop = Color(0xFFF7E9CC);
const Color kBackgroundGradientBottom = Color(0xFFFAF8F3);

/// "Text/Primary" in Figma — near-black used for titles.
const Color kTextPrimary = Color(0xFF313337);

/// "Border/Default" in Figma — 1px hairline on white cards.
const Color kBorderDefault = Color(0xFFE7E5E1);
