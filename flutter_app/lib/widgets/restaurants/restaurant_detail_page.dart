import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_review.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/restaurants/photo_viewer_page.dart';
import 'package:vegan_app/widgets/restaurants/create_restaurant_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_labels.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_report_sheets.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_share.dart';
import 'package:vegan_app/widgets/reviews/rating_status_chip.dart';
import 'package:vegan_app/widgets/reviews/rating_summary.dart';
import 'package:vegan_app/widgets/reviews/review_card.dart';
import 'package:vegan_app/widgets/reviews/review_form_sheet.dart';
import 'package:vegan_app/widgets/reviews/reviews_empty_state.dart';
import 'package:vegan_app/widgets/reviews/star_rating.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';
import 'package:vegan_app/widgets/shared/photo_source_sheet.dart';
import 'package:vegan_app/widgets/shared/square_icon_button.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Inline confirmation/error, shown next to what it is about.
typedef _Feedback = ({String text, Color color});

/// Page of a restaurant: header, then infos, photos and reviews tabs.
class RestaurantDetailPage extends StatefulWidget {
  /// The map pin; the full restaurant is loaded when the page opens.
  final Restaurant restaurant;

  const RestaurantDetailPage({super.key, required this.restaurant});

  /// Pushes the page; completes when it is closed.
  static Future<void> open(BuildContext context, Restaurant restaurant) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RestaurantDetailPage(restaurant: restaurant),
    ));
  }

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with SingleTickerProviderStateMixin {
  static const int _maxPhotosPerKind = 10;
  static const int _maxPhotosPerReview = 5;

  late Restaurant _restaurant = widget.restaurant;

  /// Map pins don't carry it: known once the full restaurant is loaded,
  /// unless the user toggled it first.
  late bool _isSaved = widget.restaurant.isSaved;
  bool _savedTouched = false;

  // Photos tab state
  bool _isUploadingPhotos = false;
  _Feedback? _photoFeedback;

  // Reviews tab state
  RestaurantReviewSummary? _summary;
  List<RestaurantReview> _reviews = [];
  bool _isLoadingReviews = true;
  bool _reviewsError = false;
  int _reviewsPage = 1;
  int _reviewsTotalPages = 1;
  RestaurantReview? _myReview;
  bool _isSendingReview = false;
  _Feedback? _reviewFeedback;

  /// Shown under the header once a suggestion was sent.
  _Feedback? _suggestionFeedback;

  /// Key of this restaurant's unsent entry in [ReviewDrafts].
  String get _reviewDraftKey => 'restaurant:${widget.restaurant.id}';

  late final TabController _tabController;

  bool get _isLoggedIn => AuthService.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _isLoadingReviews) _loadReviews();
    });
    _loadRestaurant();
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    final restaurant =
        await RestaurantApiService.getRestaurant(widget.restaurant.id);
    if (restaurant != null && mounted) {
      setState(() {
        _restaurant = restaurant;
        if (!_savedTouched) _isSaved = restaurant.isSaved;
      });
    }
  }

  Future<void> _loadSummary() async {
    final summary =
        await RestaurantApiService.getReviewSummary(widget.restaurant.id);
    if (mounted) setState(() => _summary = summary);
  }

  // ── Links ─────────────────────────────────────────────────────────────────

  Future<void> _launch(Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le lien.',
              style: TextStyle(fontSize: 44.sp)),
        ),
      );
    }
  }

  /// Optimistic: flips right away, back on failure.
  Future<void> _toggleSaved() async {
    final saved = !_isSaved;
    setState(() {
      _isSaved = saved;
      _savedTouched = true;
    });
    final ok =
        await RestaurantApiService.setRestaurantSaved(_restaurant.id, saved);
    if (!mounted) return;
    if (!ok) setState(() => _isSaved = !saved);
    // Replaces the previous one when toggled several times in a row
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(!ok
            ? 'Impossible de modifier les lieux sauvegardés, réessayez.'
            : saved
                ? 'Lieu sauvegardé'
                : 'Sauvegarde retirée'),
        backgroundColor: ok ? kSemanticSuccess : kSemanticError,
      ));
  }

  void _openItinerary() => _launch(Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${_restaurant.latitude},${_restaurant.longitude}',
      ));

  /// A full URL, a URL without scheme ("instagram.com/resto", or the
  /// website itself when [site] is the value), or a handle on [site] —
  /// which may hold dots ("@le.resto"), so a dot alone doesn't make a URL.
  static Uri _socialUrl(String value, String site) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http')) return Uri.parse(trimmed);
    if (trimmed.contains('/') || trimmed.contains(site)) {
      return Uri.parse('https://$trimmed');
    }
    return Uri.parse('https://$site/${trimmed.replaceFirst('@', '')}');
  }

  /// "@compte" from a handle or a profile URL, or [fallback] when the URL
  /// carries no readable name (e.g. facebook.com/profile.php?id=…).
  static String _socialHandle(String value, String site, String fallback) {
    var segments = _socialUrl(value, site)
        .pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    // facebook.com/p/Nom-123…/ and facebook.com/pages/Nom/123…
    if (segments.length > 1 && const ['p', 'pages'].contains(segments.first)) {
      segments = segments.sublist(1);
    }
    if (segments.isEmpty || segments.first.contains('.php')) return fallback;
    final handle = segments.first
        .replaceFirst('@', '')
        .replaceFirst(RegExp(r'-\d{6,}$'), '');
    return '@$handle';
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<void> _addPhotos() async {
    // A grocery only has photos of the place: no need to ask
    final kind = _restaurant.hasNoMenu
        ? RestaurantPhoto.kindPlace
        : await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => BottomSheetShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajouter une photo', style: AppTextStyles.baloo22),
                  SizedBox(height: 24.h),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text('Du menu', style: AppTextStyles.bodyRegular15),
                    onTap: () =>
                        Navigator.of(ctx).pop(RestaurantPhoto.kindMenu),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text('Du lieu', style: AppTextStyles.bodyRegular15),
                    onTap: () =>
                        Navigator.of(ctx).pop(RestaurantPhoto.kindPlace),
                  ),
                ],
              ),
            ),
          );
    if (kind == null || !mounted) return;

    final remaining = _maxPhotosPerKind - _restaurant.photosOfKind(kind).length;
    if (remaining <= 0) {
      setState(() => _photoFeedback = (
            text: 'Il y a déjà $_maxPhotosPerKind photos de ce type.',
            color: kSemanticError,
          ));
      return;
    }
    final files = await pickPhotos(context, max: remaining);
    if (files.isEmpty || !mounted) return;

    setState(() {
      _isUploadingPhotos = true;
      _photoFeedback = null;
    });
    var failures = 0;
    final reasons = <String>{};
    for (final file in files) {
      final result = await RestaurantApiService.uploadRestaurantPhoto(
        restaurantId: _restaurant.id,
        kind: kind,
        photo: file,
      );
      if (!result.ok) {
        failures++;
        if (result.error != null) reasons.add(result.error!);
      }
    }
    await _loadRestaurant();
    if (!mounted) return;
    final sent = files.length - failures;
    setState(() {
      _isUploadingPhotos = false;
      _photoFeedback = failures == 0
          ? (
              text: 'Merci ! Visible${sent > 1 ? 's' : ''} après validation.',
              color: kSemanticSuccess,
            )
          : (
              text: '$failures photo${failures > 1 ? 's' : ''} sur '
                  '${files.length} '
                  '${failures > 1 ? 'n\'ont' : 'n\'a'} pas pu être '
                  'envoyée${failures > 1 ? 's' : ''}'
                  '${reasons.isEmpty ? '. Réessayez !' : ' : ${reasons.join(' ')}'}',
              color: kSemanticError,
            );
    });
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<void> _loadReviews({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = false;
    });

    // A failed "my review" fetch must not pass for "no review yet": the
    // button would then post a duplicate instead of editing it.
    var myReviewFailed = false;
    final results = await Future.wait([
      RestaurantApiService.getReviews(
          restaurantId: widget.restaurant.id, page: page),
      if (_isLoggedIn)
        RestaurantApiService.getMyReview(widget.restaurant.id).catchError((_) {
          myReviewFailed = true;
          return null;
        }),
    ]);

    final paginated = results[0] as RestaurantReviewPaginated?;
    final myReview = _isLoggedIn ? results[1] as RestaurantReview? : null;

    if (!mounted) return;
    if (paginated == null || myReviewFailed) {
      setState(() {
        _isLoadingReviews = false;
        _reviewsError = true;
      });
      return;
    }

    final currentUserId = AuthService.currentUser?.id;
    setState(() {
      _reviews = paginated.items
          .where((r) => currentUserId == null || r.userId != currentUserId)
          .toList();
      _reviewsPage = page;
      _reviewsTotalPages = paginated.pages;
      _myReview = myReview;
      _isLoadingReviews = false;
    });
  }

  Future<void> _showReviewDialog({RestaurantReview? existing}) async {
    final draft = ReviewDrafts.get(_reviewDraftKey);
    final Map<String, int?> initialCriteria = {
      ...?(draft?.criteria ?? existing?.criteria),
      // A fully vegan place has the whole menu to choose from: always 5,
      // not up to the user
      if (_restaurant.isFullyVegan) 'rating_choice': 5,
    };
    final entry = await showReviewFormSheet(
      context,
      title: existing == null ? 'Laisser un avis' : 'Modifier votre avis',
      subtitle: _restaurant.name,
      initialRating: draft?.rating ?? existing?.rating,
      initialComment: draft != null ? draft.comment : existing?.comment,
      criteria: [
        for (final c in RestaurantCriterion.all)
          // Nothing to taste on the spot in a grocery
          if (!(_restaurant.hasNoMenu && c.key == 'taste')) (c.field, c.label),
      ],
      initialCriteria: initialCriteria,
      lockedCriteria: {if (_restaurant.isFullyVegan) 'rating_choice'},
      maxPhotos: _maxPhotosPerReview - (existing?.photos.length ?? 0),
      initialPhotos: draft?.photos ?? const [],
      commentHint: 'Plats, accueil, options véganes...',
      moderationNotice:
          'Les avis avec un commentaire ou des photos sont publiés après '
          'validation.',
    );
    if (entry == null || !mounted) return;

    setState(() {
      _isSendingReview = true;
      _reviewFeedback = null;
    });
    final review = existing == null
        ? await RestaurantApiService.postReview(
            restaurantId: _restaurant.id,
            rating: entry.rating,
            criteria: entry.criteria,
            comment: entry.comment,
          )
        : await RestaurantApiService.updateReview(
            reviewId: existing.id,
            rating: entry.rating,
            criteria: entry.criteria,
            comment: entry.comment,
          );
    if (!mounted) return;

    if (review == null) {
      ReviewDrafts.save(_reviewDraftKey, entry);
      setState(() {
        _isSendingReview = false;
        _reviewFeedback = (
          text: 'L\'envoi a échoué. Vérifiez votre connexion et réessayez !',
          color: kSemanticError,
        );
      });
      return;
    }

    var photoFailures = 0;
    for (final photo in entry.photos) {
      final ok = await RestaurantApiService.uploadReviewPhoto(
          reviewId: review.id, photo: photo);
      if (!ok) photoFailures++;
    }
    ReviewDrafts.clear(_reviewDraftKey);
    if (!mounted) return;

    final pending = review.status == ReviewStatus.pending ||
        entry.photos.length > photoFailures;
    setState(() {
      _isSendingReview = false;
      _reviewFeedback = photoFailures > 0
          ? (
              text: 'Avis envoyé, mais $photoFailures photo'
                  '${photoFailures > 1 ? 's' : ''} n\'a pas pu être envoyée.',
              color: kSemanticError,
            )
          : (
              text: pending
                  ? 'Avis envoyé, en attente de validation.'
                  : 'Merci pour votre avis !',
              color: kSemanticSuccess,
            );
    });
    _loadSummary();
    await _loadReviews(page: _reviewsPage);
  }

  // ── Infos tab ─────────────────────────────────────────────────────────────

  Widget _section(String title, Widget child) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.baloo22),
          SizedBox(height: 18.h),
          child,
        ],
      ),
    );
  }

  Widget _buildOpeningHours() {
    final r = _restaurant;
    if (r.openingHours.isEmpty) {
      return Text('Horaires inconnus',
          style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]));
    }
    final today = DateTime.now().weekday - 1;
    return Column(
      children: [
        for (var day = 0; day < 7; day++)
          Builder(builder: (_) {
            final slots = r.openingHours.where((s) => s.day == day).toList()
              ..sort((a, b) => a.openMinutes.compareTo(b.openMinutes));
            final style = day == today
                ? AppTextStyles.bodyBold15
                : AppTextStyles.bodyRegular15;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300.w,
                    child: Text(dayName(day, capitalize: true), style: style),
                  ),
                  Expanded(
                    child: Text(
                      slots.isEmpty
                          ? 'Fermé'
                          : slots.map((s) => s.label).join(', '),
                      style: slots.isEmpty
                          ? style.copyWith(color: Colors.grey[500])
                          : style,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _contactRow(IconData icon, String label, Uri url) {
    return InkWell(
      onTap: () => _launch(url),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(icon,
                size: 56.sp, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 24.w),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyRegular15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfosTab() {
    final r = _restaurant;
    final closure = closureText(r, DateTime.now());
    final surcharge = plantMilkSurchargeText(r.plantMilkSurcharge);
    final contacts = [
      if (r.phone != null)
        _contactRow(Icons.phone_outlined, r.phone!,
            Uri(scheme: 'tel', path: r.phone!.replaceAll(' ', ''))),
      if (r.website != null)
        _contactRow(
            Icons.language, r.website!, _socialUrl(r.website!, r.website!)),
      if (r.facebook != null)
        _contactRow(
            Icons.facebook,
            _socialHandle(r.facebook!, 'facebook.com', 'Facebook'),
            _socialUrl(r.facebook!, 'facebook.com')),
      if (r.instagram != null)
        _contactRow(
            Icons.camera_alt_outlined,
            _socialHandle(r.instagram!, 'instagram.com', 'Instagram'),
            _socialUrl(r.instagram!, 'instagram.com')),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
          48.w, 24.h, 48.w, 64.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (closure != null)
          Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: InfoBox(
              text: [closure, if (r.closureNote != null) r.closureNote!]
                  .join('\n'),
              symbol: '!',
            ),
          ),
        if (!r.hasStorefront)
          Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: InfoBox(
              text: 'Sans boutique · livraison et événements'
                  '${r.serviceArea != null ? '\nZone servie : ${r.serviceArea}' : ''}',
              icon: Icons.delivery_dining,
            ),
          ),
        if (r.serviceOptions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 36.h),
            child: Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                for (final option in r.serviceOptions)
                  TagChip(
                    label: RestaurantServiceOptions.label(option),
                    icon: switch (option) {
                      RestaurantServiceOptions.dineIn => Icons.restaurant,
                      RestaurantServiceOptions.takeaway =>
                        Icons.takeout_dining_outlined,
                      _ => Icons.delivery_dining_outlined,
                    },
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        if (!r.isFullyVegan && r.veganOptionsDetails != null)
          _section(
              'Options véganes',
              Text(r.veganOptionsDetails!,
                  style: AppTextStyles.bodyRegular15.copyWith(height: 1.3))),
        if (r.menuUrl != null)
          Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: _contactRow(Icons.menu_book_outlined, 'Voir le menu',
                _socialUrl(r.menuUrl!, r.menuUrl!)),
          ),
        if (surcharge != null)
          Padding(
            padding: EdgeInsets.only(top: 36.h),
            // Red when plant milk costs more, so it can't be missed
            child: (r.plantMilkSurcharge ?? 0) > 0
                ? InfoBox(
                    text: surcharge,
                    icon: Icons.local_cafe_outlined,
                    color: kSemanticError,
                    backgroundColor: kSemanticError.withValues(alpha: 0.08),
                  )
                : InfoBox(
                    text: surcharge,
                    icon: Icons.local_cafe_outlined,
                    color: kSemanticSuccess,
                    backgroundColor: kPrimaryTag,
                  ),
          ),
        if (r.description != null)
          _section(
              'Description',
              Text(r.description!,
                  style: AppTextStyles.bodyRegular15.copyWith(height: 1.3))),
        _section(
          r.hasStorefront ? 'Horaires' : 'Horaires de commande',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOpeningHours(),
              if (r.openingHoursNote != null) ...[
                SizedBox(height: 12.h),
                Text(r.openingHoursNote!,
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[600])),
              ],
            ],
          ),
        ),
        if (contacts.isNotEmpty)
          _section('Contact', Column(children: contacts)),
      ],
    );
  }

  // ── Photos tab ────────────────────────────────────────────────────────────

  Widget _thumbnail(List<RestaurantPhoto> gallery, int index, double size) {
    final photo = gallery[index];
    return GestureDetector(
      onTap: () => PhotoViewerPage.open(context, gallery, index),
      child: Stack(
        children: [
          ClipSmoothRect(
            radius: squircleRadius(24.r),
            child: CachedNetworkImage(
              imageUrl: photo.url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.image, color: Colors.grey[400]),
              ),
            ),
          ),
          if (photo.isPending)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const StadiumBorder(),
                ),
                child: Text('En attente',
                    style: TextStyle(fontSize: 30.sp, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoGrid(String title, List<RestaurantPhoto> photos) {
    return _section(
      title,
      photos.isEmpty
          ? Text('Aucune photo pour le moment',
              style:
                  AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]))
          : LayoutBuilder(builder: (context, constraints) {
              final size = (constraints.maxWidth - 2 * 18.w) / 3;
              return Wrap(
                spacing: 18.w,
                runSpacing: 18.w,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    _thumbnail(photos, i, size),
                ],
              );
            }),
    );
  }

  Widget _buildPhotosTab() {
    final feedback = _photoFeedback;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          48.w, 24.h, 48.w, 64.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (!_restaurant.hasNoMenu)
          _photoGrid(
              'Menu', _restaurant.photosOfKind(RestaurantPhoto.kindMenu)),
        _photoGrid('Lieu', _restaurant.photosOfKind(RestaurantPhoto.kindPlace)),
        SizedBox(height: AppSpacing.section),
        Center(
          child: AppButton(
            label: 'Ajouter une photo',
            icon: Icons.add_a_photo_outlined,
            backgroundColor: Theme.of(context).colorScheme.primary,
            isLoading: _isUploadingPhotos,
            onPressed: _addPhotos,
          ),
        ),
        if (feedback != null) ...[
          SizedBox(height: 18.h),
          Text(feedback.text,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyMedium13.copyWith(color: feedback.color)),
        ],
      ],
    );
  }

  // ── Reviews tab ───────────────────────────────────────────────────────────

  Widget _buildCriteriaSummary(RestaurantReviewSummary summary) {
    final rated = RestaurantCriterion.all
        .where((c) => (summary.criteria[c.key]?.ratingCount ?? 0) > 0)
        .toList();
    if (rated.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Column(
        children: [
          for (final criterion in rated)
            Builder(builder: (_) {
              final stats = summary.criteria[criterion.key]!;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(criterion.label,
                          style: AppTextStyles.bodyRegular15),
                    ),
                    StarRating(value: stats.ratingAvg ?? 0, size: 42.sp),
                    SizedBox(width: 12.w),
                    SizedBox(
                      width: 170.w,
                      child: Text(
                        '${formatRatingAverage(stats.ratingAvg ?? 0)} '
                        '(${stats.ratingCount})',
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Detailed ratings and photos under a review's comment.
  Widget? _reviewFooter(RestaurantReview review) {
    final rated = RestaurantCriterion.all
        .where((c) => review.criteria.containsKey(c.field))
        .toList();
    if (rated.isEmpty && review.photos.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rated.isNotEmpty)
          Wrap(
            spacing: 24.w,
            runSpacing: 8.h,
            children: [
              for (final c in rated)
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${c.label} ',
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[600]),
                  ),
                  TextSpan(
                    text: '★ ${review.criteria[c.field]}',
                    style:
                        AppTextStyles.bodyBold13.copyWith(color: kAccentYellow),
                  ),
                ])),
            ],
          ),
        if (review.photos.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.w,
            children: [
              for (var i = 0; i < review.photos.length; i++)
                _thumbnail(review.photos, i, 160.w),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMyReview() {
    final primary = Theme.of(context).colorScheme.primary;
    if (!_isLoggedIn) {
      return Text(
        'Connectez-vous pour laisser un avis.',
        style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      );
    }

    final mine = _myReview;
    if (mine != null) {
      return ReviewCard(
        nickname: mine.userNickname ?? AuthService.currentUser?.nickname,
        isPremium: mine.userIsPremium,
        rating: mine.rating,
        comment: mine.comment,
        date: mine.createdAt,
        highlighted: true,
        badge: RatingStatusChip(status: mine.status),
        footer: _reviewFooter(mine),
        trailing: _isSendingReview
            ? SizedBox(
                width: 48.sp,
                height: 48.sp,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.edit_outlined, size: 54.sp, color: primary),
        onTap:
            _isSendingReview ? null : () => _showReviewDialog(existing: mine),
      );
    }

    return Center(
      child: AppButton(
        label: 'Laisser un avis',
        icon: Icons.rate_review,
        backgroundColor: primary,
        isLoading: _isSendingReview,
        onPressed: _isSendingReview ? null : () => _showReviewDialog(),
      ),
    );
  }

  List<Widget> _buildMyReviewSection() {
    final feedback = _reviewFeedback;
    return [
      _buildMyReview(),
      if (feedback != null) ...[
        SizedBox(height: 18.h),
        Text(
          feedback.text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium13.copyWith(color: feedback.color),
        ),
      ],
    ];
  }

  Widget _buildPaginationControls() {
    if (_reviewsTotalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, size: 56.r),
          onPressed: _reviewsPage > 1
              ? () => _loadReviews(page: _reviewsPage - 1)
              : null,
        ),
        Text('$_reviewsPage / $_reviewsTotalPages',
            style: TextStyle(fontSize: 46.sp)),
        IconButton(
          icon: Icon(Icons.chevron_right, size: 56.r),
          onPressed: _reviewsPage < _reviewsTotalPages
              ? () => _loadReviews(page: _reviewsPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _summary;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          48.w, 36.h, 48.w, 24.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (_reviewsError) ...[
          const ReviewsEmptyState(
            title: 'Impossible de charger les avis',
            subtitle: 'Vérifiez votre connexion et réessayez.',
          ),
          SizedBox(height: AppSpacing.item),
          Center(
            child: AppButton(
              label: 'Réessayer',
              backgroundColor: kAccentYellow,
              onPressed: () {
                _loadSummary();
                _loadReviews(page: _reviewsPage);
              },
            ),
          ),
        ] else ...[
          if (summary != null && summary.reviewCount > 0) ...[
            RatingSummary(
              average: summary.ratingAvg,
              count: summary.reviewCount,
              distribution: summary.distribution,
            ),
            _buildCriteriaSummary(summary),
            SizedBox(height: AppSpacing.section),
          ],
          if (_reviews.isEmpty) ...[
            if (_myReview == null)
              const ReviewsEmptyState(
                  subtitle: 'Soyez la première personne à mettre un avis  🌱'),
            SizedBox(height: 20.h),
            ..._buildMyReviewSection(),
          ] else ...[
            ..._buildMyReviewSection(),
            SizedBox(height: 16.h),
            for (final review in _reviews)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.item),
                child: ReviewCard(
                  nickname: review.userNickname,
                  isPremium: review.userIsPremium,
                  rating: review.rating,
                  comment: review.comment,
                  date: review.createdAt,
                  footer: _reviewFooter(review),
                ),
              ),
            SizedBox(height: 12.h),
            _buildPaginationControls(),
          ],
        ],
      ],
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  /// The featured photo across the top, from the map pin so it shows as
  /// soon as the page opens. Tapping it opens the gallery there.
  Widget _buildFeaturedPhoto() {
    final featured =
        _restaurant.featuredPhoto ?? widget.restaurant.featuredPhoto;
    if (featured == null) return const SizedBox.shrink();
    final gallery = [
      ..._restaurant.photosOfKind(RestaurantPhoto.kindPlace),
      ..._restaurant.photosOfKind(RestaurantPhoto.kindMenu),
    ];
    final index = gallery.indexWhere((p) => p.id == featured.id);
    return Padding(
      padding: EdgeInsets.fromLTRB(48.w, 0, 48.w, 12.h),
      child: GestureDetector(
        onTap: () => index >= 0
            ? PhotoViewerPage.open(context, gallery, index)
            : PhotoViewerPage.open(context, [featured], 0),
        child: ClipSmoothRect(
          radius: squircleRadius(48.r),
          child: CachedNetworkImage(
            imageUrl: featured.url,
            height: 480.h,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 480.h, color: Colors.grey[200]),
            errorWidget: (_, __, ___) => Container(
              height: 480.h,
              color: Colors.grey[200],
              child: Icon(Icons.image, color: Colors.grey[400]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Suggestions ───────────────────────────────────────────────────────────

  Future<void> _suggest(String action) async {
    // Every use of the context happens before the first await
    final Future<bool?> report = switch (action) {
      'edit' => Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => CreateRestaurantPage.suggest(restaurant: _restaurant),
        )),
      'closure' => showClosureReportSheet(context, _restaurant),
      'no_vegan_option' => showNoVeganOptionReportSheet(context, _restaurant),
      _ => showDuplicateReportSheet(context, _restaurant),
    };
    final sent = await report;
    if (sent == true && mounted) {
      setState(() => _suggestionFeedback = (
            text: 'Merci ! Votre proposition sera vérifiée par l\'équipe.',
            color: kSemanticSuccess,
          ));
    }
  }

  /// Ways to propose a change, in a bottom sheet like the app's other
  /// choices; runs the chosen one.
  Future<void> _openSuggestSheet() async {
    final primary = Theme.of(context).colorScheme.primary;

    Widget option(String value, IconData icon, String title, String detail,
        BuildContext ctx) {
      return InkWell(
        onTap: () => Navigator.of(ctx).pop(value),
        customBorder: squircleBorder(radius: 30.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Row(
            children: [
              Container(
                width: 110.w,
                height: 110.w,
                decoration: ShapeDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: squircleBorder(radius: 30.r),
                ),
                child: Icon(icon, color: primary, size: 56.sp),
              ),
              SizedBox(width: 30.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold15),
                    Text(detail,
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BottomSheetShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child:
                  Text('Une info à corriger ?', style: AppTextStyles.baloo22),
            ),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                'Votre proposition sera vérifiée par l\'équipe.',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: 24.h),
            option('edit', Icons.edit_outlined, 'Proposer une modification',
                'Horaires, contact, photos, infos…', ctx),
            option('closure', Icons.event_busy_outlined,
                'Signaler une fermeture', 'Temporaire ou définitive', ctx),
            option(
                'no_vegan_option',
                Icons.no_food_outlined,
                'Fin des options véganes',
                'Plus rien de végane à la carte',
                ctx),
            option('duplicate', Icons.content_copy_outlined,
                'C\'est un doublon', 'Ce lieu est déjà sur la carte', ctx),
          ],
        ),
      ),
    );
    if (action != null && mounted) _suggest(action);
  }

  /// "…" button opening the ways to propose a change, for a listed
  /// restaurant.
  Widget _buildSuggestButton() {
    return Semantics(
      button: true,
      label: 'Proposer une modification',
      child: SquareIconButton(
        onTap: _openSuggestSheet,
        size: 102.w,
        radius: 30.r,
        backgroundColor: Colors.white,
        shadows: const [],
        child: Icon(Icons.more_horiz, size: 54.sp, color: kTextPrimary),
      ),
    );
  }

  /// Share, save, itinerary and "…" buttons of the header, with their
  /// spacing.
  List<Widget> _buildHeaderActions(Restaurant r) => [
        if (_isLoggedIn) ...[
          Semantics(
            button: true,
            label: _isSaved ? 'Retirer des sauvegardés' : 'Sauvegarder',
            child: SquareIconButton(
              onTap: _toggleSaved,
              size: 102.w,
              radius: 30.r,
              backgroundColor: Colors.white,
              shadows: const [],
              child: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: Theme.of(context).colorScheme.primary,
                size: 54.sp,
              ),
            ),
          ),
          SizedBox(width: 24.w),
        ],
        Semantics(
          button: true,
          label: 'Partager',
          child: Builder(
            // Its own context: the share popover points at the button
            builder: (buttonContext) => SquareIconButton(
              onTap: () => shareRestaurant(buttonContext, r, summary: _summary),
              size: 102.w,
              radius: 30.r,
              backgroundColor: Colors.white,
              shadows: const [],
              child: Icon(
                Icons.send_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 54.sp,
              ),
            ),
          ),
        ),
        if (r.hasStorefront) ...[
          SizedBox(width: 24.w),
          SquareIconButton(
            onTap: _openItinerary,
            size: 102.w,
            radius: 30.r,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            child: Icon(Icons.map, color: Colors.white, size: 54.sp),
          ),
        ],
        if (_isLoggedIn && r.validated) ...[
          SizedBox(width: 24.w),
          _buildSuggestButton(),
        ],
      ];

  Widget _buildHeader() {
    final r = _restaurant;
    final summary = _summary;
    final reviewCount = summary?.reviewCount ?? r.reviewCount;
    final ratingAvg = summary?.ratingAvg ?? r.ratingAvg;
    final location = r.hasStorefront
        ? [r.address, r.city].whereType<String>().join(', ')
        : r.city ?? '';

    // Name and vegan status beside the buttons, then address and opening
    // with the kinds of place on their right, in the room the buttons
    // leave free
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beside the name, or above it when the name would not fit
          LayoutBuilder(builder: (context, constraints) {
            final actions = _buildHeaderActions(r);
            final nameBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.baloo26),
                if (reviewCount > 0 && ratingAvg != null) ...[
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(Icons.star, size: 48.sp, color: kAccentYellow),
                      SizedBox(width: 6.w),
                      Text(
                        formatRatingAverage(ratingAvg),
                        style: TextStyle(
                          fontSize: 44.sp,
                          fontWeight: FontWeight.w600,
                          color: kAccentYellow,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text('(${formatRatingCount(reviewCount)})',
                          style: TextStyle(
                              fontSize: 40.sp, color: Colors.grey[500])),
                    ],
                  ),
                ],
                // Vegan status under the name and rating, apart from the
                // kinds of place
                SizedBox(height: 9.h),
                VeganStatusChip(isFullyVegan: r.isFullyVegan),
              ],
            );
            // Square buttons and their gaps
            final buttonCount = 1 +
                (_isLoggedIn ? 1 : 0) +
                (r.hasStorefront ? 1 : 0) +
                (_isLoggedIn && r.validated ? 1 : 0);
            final actionsWidth = buttonCount * (102.w + 24.w);
            final namePainter = TextPainter(
              text: TextSpan(text: r.name, style: AppTextStyles.baloo26),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            final nameFits =
                namePainter.width <= constraints.maxWidth - actionsWidth;
            namePainter.dispose();

            if (nameFits) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nameBlock),
                  SizedBox(width: 24.w),
                  ...actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
                SizedBox(height: 12.h),
                nameBlock,
              ],
            );
          }),
          SizedBox(height: 9.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (location.isNotEmpty)
                      Text(location,
                          style: AppTextStyles.bodyMedium15
                              .copyWith(color: Colors.grey[600])),
                    SizedBox(height: 6.h),
                    OpeningStatusLine(restaurant: r),
                    if (!r.validated) ...[
                      SizedBox(height: 12.h),
                      Text('En attente de validation',
                          style: AppTextStyles.bodyMedium13
                              .copyWith(color: kAccentYellow)),
                    ],
                  ],
                ),
              ),
              if (r.tags.isNotEmpty) ...[
                SizedBox(width: 24.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 0.4.sw),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: [
                      for (final tag in r.tags) RestaurantTagChip(tag: tag),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount = _summary?.reviewCount ?? _restaurant.reviewCount;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildFeaturedPhoto(),
              _buildHeader(),
              if (_suggestionFeedback != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(48.w, 0, 48.w, 12.h),
                  child: Text(
                    _suggestionFeedback!.text,
                    style: AppTextStyles.bodyMedium13
                        .copyWith(color: _suggestionFeedback!.color),
                  ),
                ),
              TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Infos'),
                  const Tab(text: 'Photos'),
                  Tab(text: reviewCount > 0 ? 'Avis ($reviewCount)' : 'Avis'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfosTab(),
                    _buildPhotosTab(),
                    _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
