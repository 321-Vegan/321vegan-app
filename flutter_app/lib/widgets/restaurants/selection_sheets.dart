import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../services/deep_link_service.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_dialog.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';
import '../shared/sheet_option_tile.dart';
import 'selection_card.dart';
import 'selection_editor_page.dart';

/// Same limits as the API (app/schemas/restaurant_selection.py), but the
/// note: shorter here, a few lines on the selection page.
const kMaxSelectionRestaurants = 50;
const kMaxSelectionTitleLength = 100;
const kMaxSelectionDescriptionLength = 1000;
const kMaxSelectionNoteLength = 300;

Future<T?> _showSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
}

/// Asks to confirm a destructive action (delete, refuse...). True if
/// confirmed.
Future<bool> confirmSelectionAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      image: 'lib/assets/images/characters/cow-mby.webp',
      title: title,
      message: message,
      primaryLabel: confirmLabel,
      primaryColor: kSemanticError,
      onPrimary: () => Navigator.of(dialogContext).pop(true),
      secondaryLabel: 'Annuler',
      onSecondary: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  return confirmed == true;
}

// ── Send ─────────────────────────────────────────────────────────────────────

/// Sends [selection] to someone, by friend code or by email. Completes with
/// the confirmation to show once sent, null when closed.
Future<String?> showSendSelectionSheet(
        BuildContext context, RestaurantSelection selection) =>
    _showSheet<String>(context, _SendSelectionSheet(selection: selection));

class _SendSelectionSheet extends StatefulWidget {
  final RestaurantSelection selection;

  const _SendSelectionSheet({required this.selection});

  @override
  State<_SendSelectionSheet> createState() => _SendSelectionSheetState();
}

class _SendSelectionSheetState extends State<_SendSelectionSheet> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _input = TextEditingController();
  bool _byCode = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _setMode(bool byCode) {
    if (byCode == _byCode) return;
    setState(() {
      _byCode = byCode;
      _error = null;
      _input.clear();
    });
  }

  /// The API's refusal, in words for the user.
  String _errorText(String? detail, bool notFound) {
    if (notFound) return 'Aucun compte n\'a ce code ami. Vérifiez-le !';
    final d = detail ?? '';
    if (d.contains('yourself')) {
      return _byCode
          ? 'C\'est votre propre code ami !'
          : 'C\'est votre propre adresse !';
    }
    if (d.contains('per day')) {
      return 'Vous avez envoyé beaucoup de sélections aujourd\'hui, '
          'réessayez demain.';
    }
    if (d.contains('Add a restaurant')) {
      return 'Ajoutez au moins un lieu avant d\'envoyer la sélection.';
    }
    if (d.contains('email')) return 'Cette adresse e-mail n\'est pas valide.';
    return 'L\'envoi a échoué. Vérifiez votre connexion et réessayez !';
  }

  Future<void> _send() async {
    final value = _input.text.trim();
    setState(() {
      _isSending = true;
      _error = null;
    });
    final result = await RestaurantApiService.sendSelection(
      id: widget.selection.id,
      email: _byCode ? null : value,
      friendCode: _byCode ? value : null,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(_byCode
          ? 'Sélection envoyée à ${result.recipientNickname ?? value} !'
          : 'C\'est parti ! Si $value a un compte 321 Vegan, la sélection '
              'l\'attend.');
      return;
    }
    setState(() {
      _isSending = false;
      _error = _errorText(result.error, result.notFound);
    });
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
        ClipboardData(text: DeepLinkService.selectionUrl(widget.selection)));
    if (!mounted) return;
    Navigator.of(context).pop('Lien de partage copié');
  }

  /// "Code ami" / "E-mail" switch.
  Widget _modeButton(String label, IconData icon, bool byCode) {
    final selected = _byCode == byCode;
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Material(
        color: selected ? primary : Colors.white,
        shape: squircleBorder(
          radius: 30.r,
          side: BorderSide(color: selected ? primary : kBorderDefault),
        ),
        child: InkWell(
          customBorder: squircleBorder(radius: 30.r),
          onTap: _isSending ? null : () => _setMode(byCode),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 48.sp, color: selected ? Colors.white : kTextPrimary),
                SizedBox(width: 12.w),
                Text(label,
                    style: AppTextStyles.bodyBold13.copyWith(
                        color: selected ? Colors.white : kTextPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _input.text.trim();
    final canSend = _byCode ? value.length >= 4 : _emailPattern.hasMatch(value);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Envoyer « ${widget.selection.title} »',
                style: AppTextStyles.baloo22),
            SizedBox(height: 12.h),
            Text(
              'La personne pourra accepter la sélection pour la retrouver '
              'avec ses lieux sauvegardés.',
              style:
                  AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 36.h),
            Row(
              children: [
                _modeButton('Code ami', Icons.tag_rounded, true),
                SizedBox(width: 24.w),
                _modeButton('E-mail', Icons.alternate_email_rounded, false),
              ],
            ),
            SizedBox(height: 24.h),
            if (_byCode)
              AppTextField(
                key: const ValueKey('friend_code'),
                controller: _input,
                hintText: 'Son code ami, ex : K7P2XM',
                textCapitalization: TextCapitalization.characters,
                maxLength: 32,
                enabled: !_isSending,
              )
            else
              AppTextField(
                key: const ValueKey('email'),
                controller: _input,
                hintText: 'Adresse e-mail de son compte',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !_isSending,
              ),
            SizedBox(height: 12.h),
            Text(
              _byCode
                  ? 'Son code ami est dans ses réglages, section Compte.'
                  : 'L\'adresse du compte 321 Vegan de la personne.',
              style:
                  AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
            ),
            if (_error != null) ...[
              SizedBox(height: 24.h),
              FormErrorBanner(message: _error!),
            ],
            SizedBox(height: 36.h),
            AppButton(
              label: 'Envoyer',
              icon: Icons.send_rounded,
              backgroundColor: Theme.of(context).colorScheme.primary,
              isLoading: _isSending,
              onPressed: canSend ? _send : null,
            ),
            // Only a public one: its link opens it for anyone
            if (widget.selection.isPublic) ...[
              SizedBox(height: 24.h),
              SheetOptionTile(
                icon: Icons.link_rounded,
                title: 'Copier le lien de partage',
                detail: 'Pour la partager où vous voulez',
                onTap: _copyLink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Note ─────────────────────────────────────────────────────────────────────

/// Edits why [restaurantName] is recommended. Completes with the new note
/// (null note when cleared), or null when closed without saving.
Future<({String? note})?> showSelectionNoteSheet(
  BuildContext context, {
  required String restaurantName,
  String? note,
}) =>
    _showSheet<({String? note})>(
        context, _NoteSheet(restaurantName: restaurantName, note: note));

class _NoteSheet extends StatefulWidget {
  final String restaurantName;
  final String? note;

  const _NoteSheet({required this.restaurantName, this.note});

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.restaurantName, style: AppTextStyles.baloo22),
            SizedBox(height: 12.h),
            Text(
              'Pourquoi vous le recommandez, ce qu\'il faut y goûter…',
              style:
                  AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 36.h),
            AppTextField(
              controller: _note,
              hintText: 'Le tiramisu est incroyable !',
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              maxLength: kMaxSelectionNoteLength,
              showCounter: true,
            ),
            SizedBox(height: 36.h),
            AppButton(
              label: 'Enregistrer',
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () {
                final note = _note.text.trim();
                Navigator.of(context).pop((note: note.isEmpty ? null : note));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add a restaurant ─────────────────────────────────────────────────────────

/// The user's selections with a checkbox each, to put [restaurant] in or
/// take it out, and the way to start a new selection with it.
Future<void> showAddToSelectionSheet(
    BuildContext context, Restaurant restaurant) async {
  final createNew = await _showSheet<bool>(
      context, _AddToSelectionSheet(restaurant: restaurant));
  if (createNew == true && context.mounted) {
    await SelectionEditorPage.open(context, initialRestaurants: [restaurant]);
  }
}

class _AddToSelectionSheet extends StatefulWidget {
  final Restaurant restaurant;

  const _AddToSelectionSheet({required this.restaurant});

  @override
  State<_AddToSelectionSheet> createState() => _AddToSelectionSheetState();
}

class _AddToSelectionSheetState extends State<_AddToSelectionSheet> {
  List<RestaurantSelection>? _selections;
  bool _hasError = false;

  /// Selections containing the restaurant, as toggled here.
  final Set<int> _containing = {};

  /// Requests in flight, by selection.
  final Set<int> _busy = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _hasError = false);
    final result = await RestaurantApiService.getMySelections();
    if (!mounted) return;
    setState(() {
      if (result == null) {
        _hasError = true;
        return;
      }
      _selections = result.items;
      _containing
        ..clear()
        ..addAll(result.items
            .where((s) => s.restaurantIds.contains(widget.restaurant.id))
            .map((s) => s.id));
    });
  }

  Future<void> _toggle(RestaurantSelection selection) async {
    final add = !_containing.contains(selection.id);
    if (add && selection.restaurantIds.length >= kMaxSelectionRestaurants) {
      setState(() => _error =
          'Une sélection compte au plus $kMaxSelectionRestaurants lieux.');
      return;
    }
    setState(() {
      _error = null;
      _busy.add(selection.id);
      add ? _containing.add(selection.id) : _containing.remove(selection.id);
    });
    final ok = await RestaurantApiService.setRestaurantInSelection(
      selectionId: selection.id,
      restaurantId: widget.restaurant.id,
      inSelection: add,
    );
    if (!mounted) return;
    setState(() {
      _busy.remove(selection.id);
      if (!ok) {
        add ? _containing.remove(selection.id) : _containing.add(selection.id);
        _error = 'La modification a échoué, réessayez.';
      }
    });
  }

  Widget _row(RestaurantSelection selection) {
    final checked = _containing.contains(selection.id);
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Material(
        color: Colors.white,
        shape: squircleBorder(
            radius: 36.r, side: const BorderSide(color: kBorderDefault)),
        child: InkWell(
          customBorder: squircleBorder(radius: 36.r),
          onTap: _busy.contains(selection.id) ? null : () => _toggle(selection),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Row(
              children: [
                SelectionCover(selection: selection, size: 110.w),
                SizedBox(width: 30.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selection.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold15),
                      Text(selection.countLabel,
                          style: AppTextStyles.bodyRegular13
                              .copyWith(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(
                  checked ? Icons.check_circle : Icons.add_circle_outline,
                  color: checked
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                  size: 66.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selections = _selections;
    return BottomSheetShell(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajouter à une sélection', style: AppTextStyles.baloo22),
              SizedBox(height: 36.h),
              if (_hasError)
                Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Column(
                    children: [
                      Text('Impossible de charger vos sélections',
                          style: AppTextStyles.bodyRegular15),
                      TextButton(
                          onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              else if (selections == null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.h),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else
                for (final selection in selections) _row(selection),
              if (_error != null) ...[
                FormErrorBanner(message: _error!),
                SizedBox(height: 24.h),
              ],
              AppButton(
                label: 'Nouvelle sélection',
                icon: Icons.add,
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
