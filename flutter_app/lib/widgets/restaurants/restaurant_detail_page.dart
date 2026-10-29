import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vegan_app/helpers/external_links.dart';
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
import 'package:vegan_app/widgets/restaurants/restaurant_photo_thumbnail.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_report_sheets.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_share.dart';
import 'package:vegan_app/widgets/restaurants/selection_sheets.dart';
import 'package:vegan_app/widgets/reviews/rating_status_chip.dart';
import 'package:vegan_app/widgets/reviews/rating_summary.dart';
import 'package:vegan_app/widgets/reviews/review_card.dart';
import 'package:vegan_app/widgets/reviews/restaurant_review_footer.dart';
import 'package:vegan_app/widgets/reviews/review_form_sheet.dart';
import 'package:vegan_app/widgets/reviews/reviews_empty_state.dart';
import 'package:vegan_app/widgets/reviews/star_rating.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';
import 'package:vegan_app/widgets/shared/icon_snack_bar.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';
import 'package:vegan_app/widgets/shared/photo_source_sheet.dart';
import 'package:vegan_app/widgets/shared/sheet_option_tile.dart';
import 'package:vegan_app/widgets/shared/square_icon_button.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Inline confirmation/error, shown next to what it is about.
typedef _Feedback = ({String text, Color color});

/// Page of a restaurant: header, then infos, photos and reviews tabs.
class RestaurantDetailPage extends StatefulWidget {
  /// The map pin; the full restaurant is loaded when the page opens.
  final Restaurant restaurant;

  /// Opened from a selection: what its author wrote about the place, shown
  /// at the top of the infos.
  final String? selectionNote;

  /// Who wrote [selectionNote]; null when it is the user.
  final String? selectionNoteAuthor;

  const RestaurantDetailPage({
    super.key,
    required this.restaurant,
    this.selectionNote,
    this.selectionNoteAuthor,
  });

  static Future<void> open(
    BuildContext context,
    Restaurant restaurant, {
    String? selectionNote,
    String? selectionNoteAuthor,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RestaurantDetailPage(
        restaurant: restaurant,
        selectionNote: selectionNote,
        selectionNoteAuthor: selectionNoteAuthor,
      ),
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

  /// Map pins don't carry the photos: whether there are none is known once
  /// the full restaurant is loaded.
  bool _isLoaded = false;

  /// Map pins don't carry it: known once the full restaurant is loaded,
  /// unless the user toggled it first.
  late bool _isSaved = widget.restaurant.isSaved;
  bool _savedTouched = false;

  // Photos tab state
  bool _isUploadingPhotos = false;
  _Feedback? _photoFeedback;

  /// Photos of the approved reviews with their review, shown among the
  /// place photos; loaded when the photos tab is first opened.
  List<(RestaurantPhoto, RestaurantReview)> _reviewPhotos = [];
  bool _reviewPhotosRequested = false;

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

  /// Key of this restaurant's unsent entry in [ReviewDrafts].
  String get _reviewDraftKey => 'restaurant:${widget.restaurant.id}';

  late final TabController _tabController;

  bool get _isLoggedIn => AuthService.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_reviewPhotosRequested) {
        _loadReviewPhotos();
      }
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
        _isLoaded = true;
        if (!_savedTouched) _isSaved = restaurant.isSaved;
      });
    }
  }

  Future<void> _loadSummary() async {
    final summary =
        await RestaurantApiService.getReviewSummary(widget.restaurant.id);
    if (mounted) setState(() => _summary = summary);
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
    final color = ok ? kSemanticSuccess : kSemanticError;
    // Replaces the previous one when toggled several times in a row
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(iconSnackBar(
        icon: !ok
            ? Icons.error_outline
            : saved
                ? Icons.bookmark
                : Icons.bookmark_border,
        message: !ok
            ? 'Impossible de modifier les lieux sauvegardés, réessayez.'
            : saved
                ? 'Lieu sauvegardé'
                : 'Sauvegarde retirée',
        color: color,
        // Leaves time to reach the button
        duration: Duration(seconds: ok && saved ? 4 : 2),
        actionLabel: ok && saved ? 'Ajouter à une sélection' : null,
        onAction: _openAddToSelection,
      ));
  }

  /// Also on a long press on the save button.
  void _openAddToSelection() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showAddToSelectionSheet(context, _restaurant);
  }

  /// To the food truck's stop of the day, else to the restaurant (its
  /// first stop).
  void _openItinerary() {
    final stop = _restaurant.todayStop(DateTime.now());
    openItinerary(context, stop?.latitude ?? _restaurant.latitude,
        stop?.longitude ?? _restaurant.longitude);
  }

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
                  SizedBox(height: 6.h),
                  Text('Vos propres photos, pas de captures d\'écran.',
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
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

  /// The API doesn't send review photos with the restaurant: taken from its
  /// reviews, as many as one request gives (enough for nearly every
  /// restaurant). Asked again next time the tab opens if it failed.
  Future<void> _loadReviewPhotos() async {
    _reviewPhotosRequested = true;
    final paginated = await RestaurantApiService.getReviews(
        restaurantId: widget.restaurant.id, pageSize: 100);
    if (!mounted) return;
    if (paginated == null) {
      _reviewPhotosRequested = false;
      return;
    }
    setState(() => _reviewPhotos = [
          for (final review in paginated.items)
            for (final photo in review.photos)
              if (!photo.isPending) (photo, review),
        ]);
  }

  /// The review a photo of the photos tab comes from, with all its photos.
  void _showReview(RestaurantReview review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetShell(
        child: Flexible(
          child: SingleChildScrollView(
            child: ReviewCard(
              nickname: review.userNickname,
              isPremium: review.userIsPremium,
              rating: review.rating,
              comment: review.comment,
              date: review.createdAt,
              footer: RestaurantReviewFooter.orNull(review,
                  isFullyVegan: _restaurant.isFullyVegan),
            ),
          ),
        ),
      ),
    );
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

    final paginated = results[0] as Paged<RestaurantReview>?;
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
      // No price per person in a grocery
      priceRanges: _restaurant.hasNoMenu ? const [] : RestaurantPriceRanges.all,
      initialPriceRange:
          draft != null ? draft.priceRange : existing?.priceRange,
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
            priceRange: entry.priceRange,
            comment: entry.comment,
          )
        : await RestaurantApiService.updateReview(
            reviewId: existing.id,
            rating: entry.rating,
            criteria: entry.criteria,
            priceRange: entry.priceRange,
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

  /// A food truck's stop: its name and address, its days and hours there,
  /// and a button for the way there.
  Widget _buildStop(RestaurantStop stop, {required bool isToday}) {
    final primary = Theme.of(context).colorScheme.primary;
    final where = [stop.address, stop.city]
        .whereType<String>()
        .where((part) => part != stop.title)
        .join(', ');
    String slotsOf(int day) =>
        (stop.openingHours.where((s) => s.day == day).toList()
              ..sort((a, b) => a.openMinutes.compareTo(b.openMinutes)))
            .map((s) => s.label)
            .join(', ');
    final days = {for (final s in stop.openingHours) s.day}.toList()..sort();
    final today = DateTime.now().weekday - 1;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child:
                            Text(stop.title, style: AppTextStyles.bodyBold15)),
                    if (isToday) ...[
                      SizedBox(width: 12.w),
                      TagChip(label: 'Aujourd\'hui', color: primary),
                    ],
                  ],
                ),
                if (where.isNotEmpty)
                  Text(where,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
                SizedBox(height: 6.h),
                if (days.isEmpty)
                  Text('Jours variables',
                      style: AppTextStyles.bodyRegular15
                          .copyWith(color: Colors.grey[500]))
                else
                  for (final day in days)
                    Text(
                      '${dayName(day, capitalize: true)} · ${slotsOf(day)}',
                      style: day == today
                          ? AppTextStyles.bodyBold15
                          : AppTextStyles.bodyRegular15,
                    ),
                if (stop.note != null)
                  Text(stop.note!,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.directions_outlined, color: primary),
            tooltip: 'Itinéraire',
            onPressed: () =>
                openItinerary(context, stop.latitude, stop.longitude),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, Uri url) {
    return InkWell(
      onTap: () => openExternalUrl(context, url),
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

  /// What the author of the selection the page was opened from wrote.
  Widget _buildSelectionNote(String note) {
    final primary = Theme.of(context).colorScheme.primary;
    final author = widget.selectionNoteAuthor;
    return AppCard(
      radius: 36.r,
      padding: EdgeInsets.all(30.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded, size: 54.sp, color: primary),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  author == null ? 'Votre mot' : 'Le mot de $author',
                  style: AppTextStyles.bodyBold13.copyWith(color: primary),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(note,
              style: AppTextStyles.bodyRegular15
                  .copyWith(fontStyle: FontStyle.italic, height: 1.4)),
        ],
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

    final note = widget.selectionNote;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          48.w, 24.h, 48.w, 64.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (note != null)
          Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: _buildSelectionNote(note),
          ),
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
        if (r.hasGlutenFreeOptions)
          Padding(
            padding: EdgeInsets.only(top: 36.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TagChip(
                label: 'Options sans gluten',
                icon: FontAwesomeIcons.wheatAwn,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        _section(
          r.stops.isNotEmpty
              ? 'Où trouver le food truck ?'
              : r.hasStorefront
                  ? 'Horaires'
                  : 'Horaires de commande',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.stops.isEmpty)
                _buildOpeningHours()
              else
                for (final stop in r.stops)
                  _buildStop(stop,
                      isToday: stop == r.todayStop(DateTime.now())),
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
        if (_isLoaded && r.photos.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.section),
            child: _buildNoPhotoNote(),
          ),
      ],
    );
  }

  /// Asks for a first photo; adds it from the photos tab, where the sending
  /// feedback shows.
  Widget _buildNoPhotoNote() {
    return InkWell(
      onTap: _isUploadingPhotos
          ? null
          : () {
              _tabController.animateTo(1);
              _addPhotos();
            },
      customBorder: squircleBorder(radius: 48.r),
      child: const InfoBox(
        text: 'Il manque des photos. '
            'Ajoutez-en une pour aider les autres !',
        icon: Icons.add_a_photo_outlined,
      ),
    );
  }

  // ── Photos tab ────────────────────────────────────────────────────────────

  /// [reviews]: the review of the photos coming from one, by photo id; their
  /// rating shows over them and tapping one opens it. With only those, still
  /// asks for a photo.
  Widget _photoGrid(String title, List<RestaurantPhoto> photos,
      {Map<int, RestaurantReview> reviews = const {}}) {
    final onlyFromReviews =
        photos.every((photo) => reviews.containsKey(photo.id));
    return _section(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onlyFromReviews)
            Text(
                photos.isEmpty
                    ? 'Aucune photo pour le moment. Vous pouvez en ajouter '
                        'pour nous aider !'
                    : 'Pour l\'instant, seulement des photos d\'avis. '
                        'Ajoutez des photos du lieu pour nous aider !',
                style: AppTextStyles.bodyRegular15
                    .copyWith(color: Colors.grey[500])),
          if (onlyFromReviews && photos.isNotEmpty) SizedBox(height: 24.h),
          if (photos.isNotEmpty)
            LayoutBuilder(builder: (context, constraints) {
              final size = (constraints.maxWidth - 2 * 18.w) / 3;
              return Wrap(
                spacing: 18.w,
                runSpacing: 18.w,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    Builder(builder: (context) {
                      final review = reviews[photos[i].id];
                      return RestaurantPhotoThumbnail(
                        photos: photos,
                        index: i,
                        size: size,
                        rating: review?.rating,
                        onTap:
                            review == null ? null : () => _showReview(review),
                      );
                    }),
                ],
              );
            }),
        ],
      ),
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
        _photoGrid(
          'Lieu',
          [
            ..._restaurant.photosOfKind(RestaurantPhoto.kindPlace),
            for (final (photo, _) in _reviewPhotos) photo,
          ],
          reviews: {
            for (final (photo, review) in _reviewPhotos) photo.id: review,
          },
        ),
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

  /// The vegan choice of a fully vegan place is always 5 (set by the form):
  /// not worth showing.
  bool _showsCriterion(RestaurantCriterion criterion) =>
      !(_restaurant.isFullyVegan && criterion.key == 'choice');

  Widget _buildCriteriaSummary(RestaurantReviewSummary summary) {
    final rated = RestaurantCriterion.all
        .where((c) =>
            _showsCriterion(c) &&
            (summary.criteria[c.key]?.ratingCount ?? 0) > 0)
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
        footer: RestaurantReviewFooter.orNull(mine,
            isFullyVegan: _restaurant.isFullyVegan),
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
                  footer: RestaurantReviewFooter.orNull(review,
                      isFullyVegan: _restaurant.isFullyVegan),
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

  /// Shown across the top, from the map pin so it shows as soon as the
  /// page opens.
  RestaurantPhoto? get _featuredPhoto =>
      _restaurant.featuredPhoto ?? widget.restaurant.featuredPhoto;

  /// Light status bar icons over the photo; the nav bar keeps the app's
  /// style (taken from the region at the bottom of the screen).
  static const _overPhotoOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark, // iOS: light status bar text
    statusBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
  );

  /// The featured photo edge to edge, up under the status bar, with the
  /// back button over it. Tapping it opens the gallery there.
  Widget _buildFeaturedPhoto(RestaurantPhoto featured) {
    final gallery = [
      ..._restaurant.photosOfKind(RestaurantPhoto.kindPlace),
      ..._restaurant.photosOfKind(RestaurantPhoto.kindMenu),
    ];
    final index = gallery.indexWhere((p) => p.id == featured.id);
    final topInset = MediaQuery.paddingOf(context).top;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final bottomCorner =
        SmoothRadius(cornerRadius: 60.r, cornerSmoothing: kCornerSmoothing);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overPhotoOverlayStyle,
      child: SizedBox(
        height: topInset + 660.h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => index >= 0
                  ? PhotoViewerPage.open(context, gallery, index)
                  : PhotoViewerPage.open(context, [featured], 0),
              child: ClipSmoothRect(
                radius: SmoothBorderRadius.only(
                  bottomLeft: bottomCorner,
                  bottomRight: bottomCorner,
                ),
                child: CachedNetworkImage(
                  imageUrl: featured.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
            // Keeps the status bar readable over any photo
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 150.h,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canPop)
              Positioned(
                top: topInset + 18.h,
                left: 48.w,
                child: Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: SquareIconButton(
                    onTap: () => Navigator.of(context).maybePop(),
                    size: 102.w,
                    radius: 30.r,
                    backgroundColor: Colors.white,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    // The "new" iOS chevron is centred in its glyph, unlike
                    // Icons.adaptive.arrow_back
                    child: Icon(
                        switch (Theme.of(context).platform) {
                          TargetPlatform.iOS ||
                          TargetPlatform.macOS =>
                            Icons.arrow_back_ios_new,
                          _ => Icons.arrow_back,
                        },
                        size: 54.sp,
                        color: kTextPrimary),
                  ),
                ),
              ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci ! Votre proposition sera vérifiée par '
              'l\'équipe.'),
          backgroundColor: kSemanticSuccess,
        ),
      );
    }
  }

  /// Ways to propose a change; runs the chosen one.
  Future<void> _openSuggestSheet() async {
    Widget option(String value, IconData icon, String title, String detail,
        BuildContext ctx) {
      return SheetOptionTile(
        icon: icon,
        title: title,
        detail: detail,
        onTap: () => Navigator.of(ctx).pop(value),
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
            onLongPressHint: 'Ajouter à une sélection',
            child: GestureDetector(
              onLongPress: _openAddToSelection,
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

  /// The price per person most chosen in the reviews, beside the rating;
  /// tapping it shows all the answers.
  Widget _buildPriceRange(RestaurantReviewSummary summary) {
    final style = TextStyle(fontSize: 40.sp, color: Colors.grey[600]);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPriceRanges(summary),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('  ·  ', style: style),
          Flexible(
            child: Text(
              RestaurantPriceRanges.label(summary.priceRange!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                  fontWeight: FontWeight.w600, color: kTextPrimary),
            ),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.info_outline, size: 40.sp, color: Colors.grey[500]),
        ],
      ),
    );
  }

  /// How many reviews chose each price per person.
  void _showPriceRanges(RestaurantReviewSummary summary) {
    final counts = summary.priceRangeDistribution;
    final total = counts.values.fold(0, (sum, count) => sum + count);
    final most =
        counts.values.fold(0, (max, count) => count > max ? count : max);
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prix par personne', style: AppTextStyles.baloo22),
            SizedBox(height: 12.h),
            Text(
              total == 1 ? 'D\'après 1 avis' : 'D\'après $total avis',
              style:
                  AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 36.h),
            for (final (value, label) in RestaurantPriceRanges.all)
              Builder(builder: (context) {
                final count = counts[value] ?? 0;
                final isMostChosen = value == summary.priceRange;
                return Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 270.w,
                        child: Text(
                          label,
                          style: isMostChosen
                              ? AppTextStyles.bodyBold15
                              : AppTextStyles.bodyRegular15,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: LinearProgressIndicator(
                            value: most == 0 ? 0 : count / most,
                            minHeight: 24.h,
                            color: isMostChosen ? primary : Colors.grey[400],
                            backgroundColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90.w,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
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
      ),
    );
  }

  Widget _buildHeader() {
    final r = _restaurant;
    final summary = _summary;
    final reviewCount = summary?.reviewCount ?? r.reviewCount;
    final ratingAvg = summary?.ratingAvg ?? r.ratingAvg;
    final todayStop = r.todayStop(DateTime.now());
    final location = r.stops.length > 1
        ? todayStop != null
            ? 'Aujourd\'hui : ${[
                todayStop.title,
                todayStop.city
              ].whereType<String>().toSet().join(', ')}'
            : '${r.stops.length} emplacements'
        : r.hasStorefront
            ? [r.address, r.city].whereType<String>().join(', ')
            : r.city ?? '';

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
                      if (summary?.priceRange != null)
                        Flexible(child: _buildPriceRange(summary!)),
                    ],
                  ),
                ],
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
    final featured = _featuredPhoto;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // With a photo, the back button is over it
        appBar: featured != null
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: kTextPrimary,
              ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (featured != null) ...[
                _buildFeaturedPhoto(featured),
                SizedBox(height: 18.h),
              ],
              _buildHeader(),
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
