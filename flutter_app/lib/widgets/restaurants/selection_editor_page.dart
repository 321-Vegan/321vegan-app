import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
import '../shared/photo_picker_box.dart';
import '../shared/photo_source_sheet.dart';
import '../shared/search_field.dart';
import '../settings/settings_toggle_tile.dart';
import 'selection_sheets.dart';

/// Where the autosave of an existing selection stands.
enum _SaveStatus { saved, pending, saving, failed, missingTitle }

/// Creates a selection, or edits [selection] (loaded with its items): title,
/// description, cover image, whether it is public, and the places in their
/// order, each with an optional note. A new selection is created with a
/// button; an existing one is saved automatically as it changes (the cover
/// and the publication right away). Pops with the saved selection (null
/// when nothing was saved).
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

  /// Listed for everyone; for good once saved.
  late bool _isPublic = widget.selection?.isPublic ?? false;
  bool _isPublishing = false;

  /// Cover of a new selection, sent once it is created.
  File? _newCover;

  /// Cover of an existing selection, sent as soon as picked.
  late String? _coverUrl = widget.selection?.coverUrl;
  bool _isCoverBusy = false;

  /// Whole photo the cover was cropped from, when picked here: framed
  /// again from it rather than from the cropped cover.
  File? _coverOriginal;

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
    setState(() => _status = _SaveStatus.saved);
    _flashSaved();
  }

  /// Shows "Enregistré" for a moment, after a save of the form or of the
  /// cover (unless the form itself waits to be saved).
  void _flashSaved() {
    if (_status != _SaveStatus.saved) return;
    setState(() => _showSaved = true);
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

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? kSemanticError : kSemanticSuccess,
      ));
  }

  // ── Cover ────────────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final files = await pickPhotos(context);
    if (files.isEmpty || !mounted) return;
    await _cropCover(files.first);
  }

  /// Frames the cover again: from the whole photo when it was picked here,
  /// otherwise from the saved cover.
  Future<void> _recropCover() async {
    var source = _coverOriginal;
    if (source == null) {
      setState(() => _isCoverBusy = true);
      source = await _downloadCover();
      if (!mounted) return;
      setState(() => _isCoverBusy = false);
      if (source == null) {
        _snack('Impossible de charger l\'image, réessayez.', error: true);
        return;
      }
    }
    await _cropCover(source);
  }

  /// The saved cover in a temporary file, for the crop screen.
  Future<File?> _downloadCover() async {
    try {
      final response = await http.get(Uri.parse(_coverUrl!));
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      return File('${dir.path}/selection_cover_${widget.selection!.id}')
          .writeAsBytes(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  /// Frames [source] as the cover shows on the selection page, then uses
  /// it as the cover.
  Future<void> _cropCover(File source) async {
    final cover = await cropPhoto(context, source,
        ratioX: 16, ratioY: 9, title: 'Recadrer la couverture');
    if (cover == null || !mounted) return;
    if (_isNew) {
      setState(() {
        _newCover = cover;
        _coverOriginal = source;
      });
      return;
    }
    setState(() => _isCoverBusy = true);
    final result = await RestaurantApiService.uploadSelectionCover(
        id: widget.selection!.id, image: cover);
    if (!mounted) return;
    setState(() {
      _isCoverBusy = false;
      if (result.selection != null) {
        _saved = result.selection;
        _coverUrl = result.selection!.coverUrl;
        _coverOriginal = source;
      }
    });
    if (result.selection == null) {
      _snack(result.error ?? 'L\'envoi de l\'image a échoué.', error: true);
    } else {
      _flashSaved();
    }
  }

  Future<void> _removeCover() async {
    _coverOriginal = null;
    if (_isNew) {
      setState(() => _newCover = null);
      return;
    }
    setState(() => _isCoverBusy = true);
    final id = widget.selection!.id;
    final ok = await RestaurantApiService.removeSelectionCover(id);
    // Popped with the selection as it is now
    final updated = ok ? await RestaurantApiService.getSelection(id) : null;
    if (!mounted) return;
    setState(() {
      _isCoverBusy = false;
      if (ok) {
        _coverUrl = null;
        _saved = updated ?? _saved;
      }
    });
    if (ok) {
      _flashSaved();
    } else {
      _snack('Impossible de retirer l\'image, réessayez.', error: true);
    }
  }

  // ── Publication ──────────────────────────────────────────────────────────

  /// Making it public asks first, as it is for good; a public selection
  /// can't go back.
  Future<void> _setPublic(bool value) async {
    if (!value) {
      if (_isNew) {
        setState(() => _isPublic = false);
      } else {
        _snack('Une sélection publique le reste.', error: true);
      }
      return;
    }
    if (_items.isEmpty) {
      _snack('Ajoutez au moins un lieu pour la rendre publique.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        image: 'lib/assets/images/characters/cow-mby.webp',
        title: 'Rendre la sélection publique ?',
        message: 'Tout le monde pourra la voir, avec votre pseudo, et '
            'l\'ajouter à ses lieux. Ce choix est définitif.',
        primaryLabel: 'Rendre publique',
        onPrimary: () => Navigator.of(ctx).pop(true),
        secondaryLabel: 'Annuler',
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_isNew) {
      setState(() => _isPublic = true);
      return;
    }
    if (_title.text.trim().isEmpty) {
      _snack('Une sélection a besoin d\'un titre.', error: true);
      return;
    }
    // Saved with the form as it is, so the places are there
    _saveTimer?.cancel();
    while (_saving != null) {
      await _saving;
    }
    if (!mounted) return;
    setState(() => _isPublishing = true);
    final snapshot = _snapshot();
    final description = _description.text.trim();
    final result = await RestaurantApiService.updateSelection(
      id: widget.selection!.id,
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      items: [..._items],
      makePublic: true,
    );
    if (!mounted) return;
    setState(() {
      _isPublishing = false;
      if (result.selection != null) {
        _isPublic = true;
        _saved = result.selection;
        _savedSnapshot = snapshot;
      }
    });
    if (result.selection == null) {
      _snack('La publication a échoué, réessayez.', error: true);
      return;
    }
    _scheduleSave(Duration.zero);
    _snack('Sélection publique');
  }

  /// Creates the new selection, then sends its cover.
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
      isPublic: _isPublic,
    );
    if (!mounted) return;
    var created = result.selection;
    if (created != null) {
      if (_newCover != null) {
        final upload = await RestaurantApiService.uploadSelectionCover(
            id: created.id, image: _newCover!);
        if (!mounted) return;
        if (upload.selection != null) {
          created = upload.selection;
        } else {
          _snack(
              'Sélection créée, mais l\'image n\'a pas pu être envoyée : '
              'ajoutez-la en la modifiant.',
              error: true);
        }
      }
      Navigator.of(context).pop(created);
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
        SizedBox(height: 36.h),
        Text('Image de couverture (facultatif)',
            style: AppTextStyles.bodyBold15),
        SizedBox(height: 12.h),
        _buildCover(),
        SizedBox(height: 36.h),
        SettingsToggleTile(
          title: _isPublishing ? 'Publication…' : 'Publique',
          subtitle: _isPublic && !_isNew
              ? 'Visible de tous, qui peuvent l\'ajouter à leurs lieux. '
                  'C\'est définitif.'
              : 'Tout le monde pourra la voir et l\'ajouter à ses lieux.',
          value: _isPublic,
          onChanged: _isSaving || _isPublishing ? (_) {} : _setPublic,
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

  /// The chosen image with change and remove buttons over it, or the
  /// dashed box of the other photo forms (the photos of the places show
  /// otherwise).
  Widget _buildCover() {
    final busy = _isSaving || _isCoverBusy;
    final Widget? image = _newCover != null
        ? Image.file(_newCover!, fit: BoxFit.cover)
        : _coverUrl != null
            ? CachedNetworkImage(
                imageUrl: _coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.grey[100]),
              )
            : null;
    if (image == null && !_isCoverBusy) {
      return PhotoPickerBox(
        photo: null,
        onPickPhoto: _pickCover,
        onRemovePhoto: _removeCover,
        isLoading: busy,
        label: 'Ajouter une image de couverture',
      );
    }
    return ClipSmoothRect(
      radius: squircleRadius(40.r),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image ?? Container(color: Colors.grey[100]),
            if (_isCoverBusy)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              Positioned(
                top: 24.w,
                right: 24.w,
                child: Row(
                  children: [
                    _coverAction(
                      icon: Icons.crop,
                      tooltip: 'Recadrer l\'image',
                      color: kTextPrimary,
                      onTap: busy ? null : _recropCover,
                    ),
                    SizedBox(width: 18.w),
                    _coverAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Changer l\'image',
                      color: kTextPrimary,
                      onTap: busy ? null : _pickCover,
                    ),
                    SizedBox(width: 18.w),
                    _coverAction(
                      icon: Icons.close,
                      tooltip: 'Retirer l\'image',
                      color: kSemanticError,
                      onTap: busy ? null : _removeCover,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Round white button over the cover image.
  Widget _coverAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: Icon(icon, size: 54.sp, color: color),
          ),
        ),
      ),
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
                        backgroundColor: kAccentYellow,
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
