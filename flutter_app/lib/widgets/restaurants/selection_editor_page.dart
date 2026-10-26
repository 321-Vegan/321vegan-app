import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_background.dart';
import '../shared/app_button.dart';
import '../shared/app_dialog.dart';
import '../shared/app_text_field.dart';
import '../shared/form_error_banner.dart';
import '../shared/search_field.dart';
import 'selection_sheets.dart';

/// Where the autosave of an existing selection stands.
enum _SaveStatus { saved, pending, saving, failed, missingTitle }

/// Creates a selection, or edits [selection] (loaded with its items): title,
/// description, and the places in their order, each with an optional note.
/// A new selection is created with a button; an existing one is saved
/// automatically as it changes. Pops with the saved selection (null when
/// nothing was saved).
class SelectionEditorPage extends StatefulWidget {
  final RestaurantSelection? selection;

  /// Places of a new selection (e.g. the restaurant it was started from).
  final List<Restaurant> initialRestaurants;

  const SelectionEditorPage({
    super.key,
    this.selection,
    this.initialRestaurants = const [],
  });

  static Future<RestaurantSelection?> open(
    BuildContext context, {
    RestaurantSelection? selection,
    List<Restaurant> initialRestaurants = const [],
  }) {
    return Navigator.of(context).push<RestaurantSelection>(MaterialPageRoute(
      builder: (_) => SelectionEditorPage(
        selection: selection,
        initialRestaurants: initialRestaurants,
      ),
    ));
  }

  @override
  State<SelectionEditorPage> createState() => _SelectionEditorPageState();
}

class _SelectionEditorPageState extends State<SelectionEditorPage> {
  late final _title = TextEditingController(text: widget.selection?.title);
  late final _description =
      TextEditingController(text: widget.selection?.description);
  late final List<RestaurantSelectionItem> _items = widget.selection != null
      ? [...widget.selection!.items]
      : [
          for (final r in widget.initialRestaurants)
            RestaurantSelectionItem(restaurant: r),
        ];
  // Creation (new selection)
  bool _isSaving = false;
  String? _error;

  // Autosave (existing selection)
  _SaveStatus _status = _SaveStatus.saved;
  Timer? _saveTimer;

  /// "Enregistré" shows for a moment after a save, then fades out.
  bool _showSaved = false;
  Timer? _hideSavedTimer;

  /// The save in flight, if any.
  Future<void>? _saving;

  /// The form as last saved, to save only real changes.
  late String _savedSnapshot;

  /// Last version saved, popped on leaving.
  RestaurantSelection? _saved;
  bool _isLeaving = false;

  bool get _isNew => widget.selection == null;

  @override
  void initState() {
    super.initState();
    _savedSnapshot = _snapshot();
    _title.addListener(_onTextChanged);
    _description.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _hideSavedTimer?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // ── Autosave ─────────────────────────────────────────────────────────────

  /// What the API stores of the form.
  String _snapshot() => jsonEncode({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'items': [
          for (final item in _items) [item.restaurant.id, item.note],
        ],
      });

  /// Also called on cursor moves: only real changes are saved.
  void _onTextChanged() {
    setState(() {});
    _scheduleSave(const Duration(milliseconds: 800));
  }

  /// Places, order and notes are saved almost right away.
  void _onItemsChanged() => _scheduleSave(const Duration(milliseconds: 300));

  void _scheduleSave(Duration delay) {
    if (_isNew) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    final _SaveStatus status;
    if (_title.text.trim().isEmpty) {
      status = _SaveStatus.missingTitle;
    } else if (_snapshot() == _savedSnapshot) {
      status = _saving != null ? _SaveStatus.saving : _SaveStatus.saved;
    } else {
      _saveTimer = Timer(delay, _autosave);
      status = _SaveStatus.pending;
    }
    if (status != _status) setState(() => _status = status);
  }

  /// Saves the form if it changed; one save at a time, the changes made
  /// meanwhile are saved right after.
  Future<void> _autosave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    // No await between this loop and setting _saving: a second caller
    // waits for this save in turn
    while (_saving != null) {
      await _saving;
    }
    final snapshot = _snapshot();
    if (!mounted || snapshot == _savedSnapshot || _title.text.trim().isEmpty) {
      return;
    }
    final done = Completer<void>();
    _saving = done.future;
    setState(() => _status = _SaveStatus.saving);
    final description = _description.text.trim();
    final result = await RestaurantApiService.updateSelection(
      id: widget.selection!.id,
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      items: [..._items],
    );
    _saving = null;
    done.complete();
    if (!mounted) return;
    if (result.selection == null) {
      setState(() => _status = _SaveStatus.failed);
      return;
    }
    _saved = result.selection;
    _savedSnapshot = snapshot;
    if (_snapshot() != snapshot) {
      // Changed while saving
      return _autosave();
    }
    setState(() {
      _status = _SaveStatus.saved;
      _showSaved = true;
    });
    _hideSavedTimer?.cancel();
    _hideSavedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  /// Saves what is left before leaving; asks first if it can't be saved.
  Future<void> _leave() async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _autosave();
    if (!mounted) return;
    if (_snapshot() != _savedSnapshot) {
      final quit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          image: 'lib/assets/images/characters/cow-mby.webp',
          title: 'Modifications non enregistrées',
          message: _title.text.trim().isEmpty
              ? 'Une sélection a besoin d\'un titre.'
              : 'L\'enregistrement a échoué. Vérifiez votre connexion.',
          primaryLabel: 'Rester',
          onPrimary: () => Navigator.of(ctx).pop(false),
          secondaryLabel: 'Quitter sans enregistrer',
          onSecondary: () => Navigator.of(ctx).pop(true),
        ),
      );
      if (quit != true || !mounted) {
        _isLeaving = false;
        return;
      }
    }
    Navigator.of(context).pop(_saved);
  }

  Future<void> _addPlaces() async {
    final picked = await pickSelectionRestaurants(context, _items);
    if (picked.isEmpty || !mounted) return;
    setState(() => _items
        .addAll(picked.map((r) => RestaurantSelectionItem(restaurant: r))));
    _onItemsChanged();
  }

  Future<void> _editNote(int index) async {
    final item = _items[index];
    final result = await showSelectionNoteSheet(
      context,
      restaurantName: item.restaurant.name,
      note: item.note,
    );
    if (result == null || !mounted) return;
    setState(() => _items[index] = item.copyWith(note: result.note));
    _onItemsChanged();
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
    _onItemsChanged();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // The list is given the index before the item is removed
      if (newIndex > oldIndex) newIndex -= 1;
      _items.insert(newIndex, _items.removeAt(oldIndex));
    });
    _onItemsChanged();
  }

  /// Creates the new selection.
  Future<void> _create() async {
    final description = _description.text.trim();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final result = await RestaurantApiService.createSelection(
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      items: _items,
    );
    if (!mounted) return;
    if (result.selection != null) {
      Navigator.of(context).pop(result.selection);
      return;
    }
    setState(() {
      _isSaving = false;
      _error = result.error != null && result.error!.contains('more than')
          ? 'Vous avez atteint le nombre maximum de sélections.'
          : 'L\'enregistrement a échoué. Vérifiez votre connexion et '
              'réessayez !';
    });
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Titre', style: AppTextStyles.bodyBold15),
        SizedBox(height: 6.h),
        AppTextField(
          controller: _title,
          hintText: 'Mes brunchs préférés à Lyon',
          textCapitalization: TextCapitalization.sentences,
          maxLength: kMaxSelectionTitleLength,
          showCounter: true,
          enabled: !_isSaving,
        ),
        SizedBox(height: 36.h),
        Text('Description (facultatif)', style: AppTextStyles.bodyBold15),
        SizedBox(height: 6.h),
        AppTextField(
          controller: _description,
          hintText: 'Pour qui, pour quelle occasion…',
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 5,
          maxLength: kMaxSelectionDescriptionLength,
          showCounter: true,
          enabled: !_isSaving,
        ),
        SizedBox(height: AppSpacing.section),
        Row(
          children: [
            Expanded(
              child: Text('Lieux (${_items.length})',
                  style: AppTextStyles.baloo22),
            ),
            if (_items.length > 1)
              Text('Glissez pour réordonner',
                  style: AppTextStyles.bodyRegular13
                      .copyWith(color: Colors.grey[600])),
          ],
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final r = item.restaurant;
    final note = item.note;
    return Padding(
      key: ValueKey(r.id),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Material(
        color: Colors.white,
        shape: squircleBorder(
            radius: 36.r, side: const BorderSide(color: kBorderDefault)),
        child: InkWell(
          customBorder: squircleBorder(radius: 36.r),
          onTap: _isSaving ? null : () => _editNote(index),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 24.h, 12.w, 24.h),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  enabled: !_isSaving,
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Icon(Icons.drag_indicator, color: Colors.grey[400]),
                  ),
                ),
                ClipSmoothRect(
                  radius: squircleRadius(18.r),
                  child: r.featuredPhoto != null
                      ? CachedNetworkImage(
                          imageUrl: r.featuredPhoto!.url,
                          width: 120.w,
                          height: 120.w,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
                SizedBox(width: 24.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold15),
                      SizedBox(height: 4.h),
                      Text(
                        note ?? 'Ajouter une description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyRegular13.copyWith(
                          color: note != null
                              ? Colors.grey[700]
                              : Theme.of(context).colorScheme.primary,
                          fontStyle: note != null
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: Icon(Icons.close, color: Colors.grey[500]),
                  onPressed: _isSaving ? null : () => _remove(index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _thumbPlaceholder() => Container(
        width: 120.w,
        height: 120.w,
        color: Colors.grey[100],
        child: Icon(Icons.restaurant, color: Colors.grey[400]),
      );

  @override
  Widget build(BuildContext context) {
    final canAdd = _items.length < kMaxSelectionRestaurants;
    final page = AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isNew ? 'Nouvelle sélection' : 'Modifier la sélection',
              style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 24.h,
                      AppSpacing.pageHorizontal, 32.h),
                  buildDefaultDragHandles: false,
                  header: _buildFields(),
                  itemCount: _items.length,
                  itemBuilder: (_, index) => _buildItem(index),
                  onReorder: _reorder,
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'Ajouter des lieux',
                        icon: Icons.add,
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        borderColor: Theme.of(context).colorScheme.primary,
                        onPressed: canAdd && !_isSaving ? _addPlaces : null,
                      ),
                      if (!canAdd) ...[
                        SizedBox(height: 12.h),
                        Text(
                          'Une sélection compte au plus '
                          '$kMaxSelectionRestaurants lieux.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyRegular13
                              .copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 12.h,
                    AppSpacing.pageHorizontal, 24.h),
                child: _isNew
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            FormErrorBanner(message: _error!),
                            SizedBox(height: 24.h),
                          ],
                          AppButton(
                            label: 'Créer la sélection',
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            isLoading: _isSaving,
                            onPressed:
                                _title.text.trim().isNotEmpty ? _create : null,
                          ),
                        ],
                      )
                    : _buildSaveStatus(),
              ),
            ],
          ),
        ),
      ),
    );
    if (_isNew) return page;
    // Everything saved: a plain pop (the iOS back swipe keeps working).
    // Otherwise saves what is left first, then pops with the saved selection
    return PopScope<RestaurantSelection>(
      canPop: _status == _SaveStatus.saved && _saving == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: page,
    );
  }

  /// Where the autosave stands, under the form.
  Widget _buildSaveStatus() {
    final grey = Colors.grey[600]!;
    final (IconData? icon, String text, Color color) = switch (_status) {
      _SaveStatus.saved => (
          Icons.check_circle_outline,
          'Enregistré',
          kSemanticSuccess
        ),
      _SaveStatus.pending || _SaveStatus.saving => (
          null,
          'Enregistrement…',
          grey
        ),
      _SaveStatus.failed => (
          Icons.error_outline,
          'Modifications non enregistrées',
          kSemanticError
        ),
      _SaveStatus.missingTitle => (
          Icons.error_outline,
          'Le titre est obligatoire',
          kSemanticError
        ),
    };
    // The room stays, so the list doesn't jump when it fades out
    return SizedBox(
      height: 72.h,
      child: AnimatedOpacity(
        opacity: _status != _SaveStatus.saved || _showSaved ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: color, size: 48.sp)
            else
              SizedBox(
                width: 36.sp,
                height: 36.sp,
                child: CircularProgressIndicator(strokeWidth: 2, color: grey),
              ),
            SizedBox(width: 15.w),
            Text(text,
                style: AppTextStyles.bodyMedium13.copyWith(color: color)),
            if (_status == _SaveStatus.failed)
              TextButton(onPressed: _autosave, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

/// Places to add to a selection holding [items], in the order they were
/// picked (empty when none), within the selection's limit.
Future<List<Restaurant>> pickSelectionRestaurants(
    BuildContext context, List<RestaurantSelectionItem> items) async {
  final picked = await Navigator.of(context).push<List<Restaurant>>(
    MaterialPageRoute(
      builder: (_) => _RestaurantPickerPage(
        alreadyIn: {for (final item in items) item.restaurant.id},
        maxCount: kMaxSelectionRestaurants - items.length,
      ),
    ),
  );
  return picked ?? const [];
}

/// Picks places to add to a selection: the saved ones, or found by name or
/// city.
/// Pops with the picked ones, in the order they were picked.
class _RestaurantPickerPage extends StatefulWidget {
  /// Already in the selection, shown checked and not pickable.
  final Set<int> alreadyIn;
  final int maxCount;

  const _RestaurantPickerPage(
      {required this.alreadyIn, required this.maxCount});

  @override
  State<_RestaurantPickerPage> createState() => _RestaurantPickerPageState();
}

class _RestaurantPickerPageState extends State<_RestaurantPickerPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Restaurant>? _saved;
  List<Restaurant>? _results;
  bool _isSearching = false;
  bool _hasError = false;
  final List<Restaurant> _picked = [];

  bool get _isSearch => _query.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final result = await RestaurantApiService.getSavedRestaurants(pageSize: 50);
    if (!mounted) return;
    setState(() {
      _saved = result?.items ?? [];
      _hasError = result == null;
    });
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    setState(() {});
    if (!_isSearch) return;
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    setState(() => _isSearching = true);
    final results = await RestaurantApiService.searchRestaurants(query,
        includeCity: true, limit: 50);
    // A newer search went out meanwhile
    if (!mounted || _query.text.trim() != query) return;
    setState(() {
      _isSearching = false;
      _results = results;
      _hasError = results == null;
    });
  }

  void _toggle(Restaurant restaurant) {
    setState(() {
      final index = _picked.indexWhere((r) => r.id == restaurant.id);
      if (index >= 0) {
        _picked.removeAt(index);
      } else if (_picked.length < widget.maxCount) {
        _picked.add(restaurant);
      }
    });
  }

  Widget _row(Restaurant r) {
    final inSelection = widget.alreadyIn.contains(r.id);
    final picked = _picked.any((p) => p.id == r.id);
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
      onTap: inSelection ? null : () => _toggle(r),
      title: Text(r.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyBold15),
      subtitle: Text(
        inSelection ? 'Déjà dans la sélection' : (r.city ?? ''),
        style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
      ),
      trailing: Icon(
        inSelection || picked ? Icons.check_circle : Icons.add_circle_outline,
        color: inSelection
            ? Colors.grey[400]
            : picked
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[400],
        size: 66.sp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _isSearch ? _results : _saved;
    final loading =
        _isSearch ? (_isSearching && _results == null) : _saved == null;
    final String emptyText;
    if (_hasError) {
      emptyText = 'Impossible de charger les lieux, vérifiez votre connexion.';
    } else if (_isSearch) {
      emptyText = 'Aucun lieu trouvé pour « ${_query.text.trim()} »';
    } else {
      emptyText =
          'Aucun lieu sauvegardé : cherchez un lieu par son nom ou sa ville.';
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Ajouter des lieux', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 12.h),
                SearchField(
                  controller: _query,
                  hintText: 'Nom du lieu ou ville',
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                ),
                SizedBox(height: 24.h),
                if (!_isSearch)
                  Text('Vos lieux sauvegardés',
                      style: AppTextStyles.bodyBold15),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : (list == null || list.isEmpty)
                          ? Center(
                              child: Text(emptyText,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyRegular15
                                      .copyWith(color: Colors.grey[600])),
                            )
                          : ListView(
                              children: [for (final r in list) _row(r)],
                            ),
                ),
                if (_picked.length >= widget.maxCount)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Text(
                      'Une sélection compte au plus '
                      '$kMaxSelectionRestaurants lieux.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600]),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 24.h),
                  child: AppButton(
                    label: _picked.isEmpty
                        ? 'Ajouter'
                        : 'Ajouter (${_picked.length})',
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_picked),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
