import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../models/restaurants/restaurant.dart';
import '../../models/restaurants/restaurant_suggestion.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';

typedef _SendResult = ({bool ok, String? error});

/// Bottom sheet frame shared by the quick reports: title, the report's own
/// fields, an optional comment, and the send button. Pops `true` once sent.
class _ReportSheet extends StatefulWidget {
  final String title;
  final String? intro;
  final List<Widget> Function(BuildContext context, VoidCallback refresh)
      fields;
  final String sendLabel;
  final bool Function() canSend;
  final Future<_SendResult> Function(String? comment) send;

  const _ReportSheet({
    required this.title,
    this.intro,
    required this.fields,
    required this.sendLabel,
    required this.canSend,
    required this.send,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _comment = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _error = null;
    });
    final comment = _comment.text.trim();
    final result = await widget.send(comment.isEmpty ? null : comment);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSending = false;
      _error = result.error ??
          'L\'envoi a échoué. Vérifiez votre connexion et réessayez !';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
        child: Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: AppTextStyles.baloo22),
                if (widget.intro != null) ...[
                  SizedBox(height: 12.h),
                  Text(widget.intro!,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
                ],
                SizedBox(height: 36.h),
                ...widget.fields(context, () => setState(() {})),
                SizedBox(height: 36.h),
                Text('Un commentaire ? (facultatif)',
                    style: AppTextStyles.bodyBold15),
                SizedBox(height: 6.h),
                AppTextField(
                  controller: _comment,
                  hintText: 'Ce que vous avez constaté, et quand',
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  enabled: !_isSending,
                ),
                if (_error != null) ...[
                  SizedBox(height: 24.h),
                  FormErrorBanner(message: _error!),
                ],
                SizedBox(height: 36.h),
                AppButton(
                  label: widget.sendLabel,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  isLoading: _isSending,
                  onPressed: widget.canSend() ? _send : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _showReport(BuildContext context, _ReportSheet sheet) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
  return sent == true;
}

Widget _choice(
    BuildContext context, String label, bool selected, VoidCallback onTap) {
  final primary = Theme.of(context).colorScheme.primary;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 21.h),
      decoration: ShapeDecoration(
        color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
        shape: squircleBorder(
          radius: 100.r,
          side: BorderSide(
            color: selected ? primary : kBorderDefault,
            width: selected ? 1.5 : 1,
          ),
        ),
      ),
      child: Text(label,
          style: AppTextStyles.bodyMedium13
              .copyWith(color: selected ? primary : kTextPrimary)),
    ),
  );
}

String _apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Reports a closure (temporary, with optional dates, or for good), or a
/// reopening when the place is marked closed. True once sent.
Future<bool> showClosureReportSheet(
    BuildContext context, Restaurant restaurant) async {
  var status = restaurant.operatingStatus == OperatingStatus.open
      ? OperatingStatus.temporarilyClosed
      : OperatingStatus.open;
  DateTime? from;
  DateTime? until;
  final note = TextEditingController();
  final date = DateFormat.yMMMd('fr_FR');

  Future<DateTime?> pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
  }

  final sent = await _showReport(
    context,
    _ReportSheet(
      title: 'Signaler une fermeture',
      intro: restaurant.name,
      sendLabel: 'Envoyer',
      canSend: () => from == null || until == null || !from!.isAfter(until!),
      fields: (context, refresh) => [
        Wrap(
          spacing: 18.w,
          runSpacing: 18.h,
          children: [
            for (final (value, label) in [
              (OperatingStatus.temporarilyClosed, 'Fermé temporairement'),
              (OperatingStatus.permanentlyClosed, 'Fermé définitivement'),
              if (restaurant.operatingStatus != OperatingStatus.open)
                (OperatingStatus.open, 'De nouveau ouvert'),
            ])
              _choice(context, label, status == value, () {
                status = value;
                refresh();
              }),
          ],
        ),
        if (status == OperatingStatus.temporarilyClosed) ...[
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    from = await pickDate(context, from) ?? from;
                    refresh();
                  },
                  child: Text(
                      from == null ? 'Depuis…' : 'Du ${date.format(from!)}'),
                ),
              ),
              SizedBox(width: 18.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    until = await pickDate(context, until ?? from) ?? until;
                    refresh();
                  },
                  child: Text(until == null
                      ? 'Jusqu\'au…'
                      : 'Au ${date.format(until!)}'),
                ),
              ),
            ],
          ),
          if (from != null && until != null && from!.isAfter(until!)) ...[
            SizedBox(height: 12.h),
            Text('La fin doit être après le début.',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: kSemanticError)),
          ],
        ],
        if (status != OperatingStatus.open) ...[
          SizedBox(height: 24.h),
          AppTextField(
            controller: note,
            hintText: 'Précision affichée (ex : congés d\'été, travaux)',
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ],
      send: (comment) {
        final temporary = status == OperatingStatus.temporarilyClosed;
        final closureNote = note.text.trim();
        return RestaurantApiService.createSuggestion(
          restaurantId: restaurant.id,
          changes: {
            'operating_status': status,
            'closed_from': temporary && from != null ? _apiDate(from!) : null,
            'closed_until':
                temporary && until != null ? _apiDate(until!) : null,
            'closure_note':
                status == OperatingStatus.open || closureNote.isEmpty
                    ? null
                    : closureNote,
          },
          comment: comment,
        );
      },
    ),
  );
  note.dispose();
  return sent;
}

/// Reports that the place no longer has any vegan option, so it should be
/// delisted. True once sent.
Future<bool> showNoVeganOptionReportSheet(
    BuildContext context, Restaurant restaurant) {
  return _showReport(
    context,
    _ReportSheet(
      title: 'Fin des options véganes ?',
      intro: '${restaurant.name} n\'a plus d\'option végane bien identifiée : '
          'si l\'équipe le confirme, le lieu sera retiré de la carte.',
      sendLabel: 'Signaler',
      canSend: () => true,
      fields: (_, __) => const [],
      send: (comment) => RestaurantApiService.createSuggestion(
        restaurantId: restaurant.id,
        kind: RestaurantSuggestion.kindNoVeganOption,
        comment: comment,
      ),
    ),
  );
}

/// Reports that the place already exists on the map as a nearby one. True
/// once sent.
Future<bool> showDuplicateReportSheet(
    BuildContext context, Restaurant restaurant) async {
  final nearby = await RestaurantApiService.getNearbyRestaurants(
    latitude: restaurant.latitude,
    longitude: restaurant.longitude,
    radius: 300,
  );
  if (!context.mounted) return false;
  final candidates = (nearby ?? [])
      .where((r) => r.id != restaurant.id && r.validated)
      .toList();
  Restaurant? selected;

  return _showReport(
    context,
    _ReportSheet(
      title: 'C\'est un doublon',
      intro: 'Choisissez le lieu qui existe déjà : avis et photos y seront '
          'regroupés.',
      sendLabel: 'Signaler',
      canSend: () => selected != null,
      fields: (context, refresh) => [
        if (candidates.isEmpty)
          Text('Aucun lieu proche trouvé.',
              style:
                  AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]))
        else
          for (final candidate in candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                selected?.id == candidate.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(candidate.name, style: AppTextStyles.bodyMedium15),
              onTap: () {
                selected = candidate;
                refresh();
              },
            ),
      ],
      send: (comment) => RestaurantApiService.createSuggestion(
        restaurantId: restaurant.id,
        kind: RestaurantSuggestion.kindDuplicate,
        duplicateOfId: selected!.id,
        comment: comment,
      ),
    ),
  );
}
