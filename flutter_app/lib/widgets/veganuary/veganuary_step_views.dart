import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../helpers/external_links.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../pages/app_pages/Profile/b12_info_page.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../b12/b12_reminder_settings_modal.dart';
import '../shared/animated_reveal.dart';
import '../shared/attention_pulse.dart';
import '../shared/app_button.dart';
import '../shared/info_box.dart';

/// Pages of a Veganuary day: one view per kind of step, shown by
/// VeganuaryDayPage between its progress bar and its button.

TextStyle get _bodyStyle => AppTextStyles.bodyRegular15.copyWith(
      color: Colors.grey[700],
      height: 1.4,
    );

/// The page's kind ("Idée reçue"...), at the left right above its title.
List<Widget> _tagAbove(Widget? tag) => tag == null
    ? const []
    : [
        Align(alignment: AlignmentDirectional.centerStart, child: tag),
        SizedBox(height: 24.h),
      ];

/// `[1]`: the first source of the page.
final _sourceRef = RegExp(r'\[\d+\]');

/// The sources of the page around, for its `[1]` references to open them.
class _SourcesScope extends InheritedWidget {
  final List<VeganuarySource> sources;

  const _SourcesScope({required this.sources, required super.child});

  static List<VeganuarySource> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SourcesScope>()?.sources ??
      const [];

  @override
  bool updateShouldNotify(_SourcesScope oldWidget) =>
      sources != oldWidget.sources;
}

/// [text] with its `**…**` parts in bold, and its `[1]`-like references
/// to the page's sources highlighted, each opening its source.
class VeganuaryRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const VeganuaryRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? _bodyStyle;
    final parts = text.split('**');
    final refStyle = base.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
    final sources = _SourcesScope.of(context);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          // Odd parts were between two `**`
          for (int i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(
                style: i.isOdd
                    ? const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      )
                    : null,
                children: _withSourceRefs(context, parts[i], refStyle, sources),
              ),
        ],
      ),
      textAlign: textAlign,
    );
  }

  static List<InlineSpan> _withSourceRefs(
    BuildContext context,
    String text,
    TextStyle refStyle,
    List<VeganuarySource> sources,
  ) {
    final spans = <InlineSpan>[];
    text.splitMapJoin(
      _sourceRef,
      onMatch: (match) {
        final ref = match[0]!;
        final n = int.parse(ref.substring(1, ref.length - 1));
        if (n < 1 || n > sources.length) {
          spans.add(TextSpan(text: ref, style: refStyle));
          return '';
        }
        final source = sources[n - 1];
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            link: true,
            label: 'Source $n : ${source.label}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openExternalUrl(context, Uri.parse(source.url)),
              child: Text(ref, style: refStyle),
            ),
          ),
        ));
        return '';
      },
      onNonMatch: (part) {
        if (part.isNotEmpty) spans.add(TextSpan(text: part));
        return '';
      },
    );
    return spans;
  }
}

/// Image of the content: an asset path, or a URL.
class VeganuaryImage extends StatelessWidget {
  final String src;
  final double? height;
  final BoxFit fit;

  const VeganuaryImage(
    this.src, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        height: height,
        width: double.infinity,
        fit: fit,
        placeholder: (context, url) =>
            Container(height: height ?? 450.h, color: kBorderDefault),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    }
    return Image.asset(
      src,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Scrolls when longer than the screen, centered vertically otherwise.
class _CenteredScroll extends StatelessWidget {
  final Widget child;

  const _CenteredScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal, vertical: 48.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 96.h),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class VeganuaryInfoView extends StatelessWidget {
  final VeganuaryInfo info;

  /// Grid cards whose details were read: checked.
  final Set<GridItem> seenCards;

  /// A grid card's details were just read (closed).
  final ValueChanged<GridItem>? onCardSeen;

  /// Above the title: what kind of page it is.
  final Widget? tag;

  const VeganuaryInfoView({
    super.key,
    required this.info,
    this.seenCards = const {},
    this.onCardSeen,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredScroll(
      child: _SourcesScope(
        sources: info.sources,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._tagAbove(tag),
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.baloo36,
            ),
            for (final block in info.blocks) ...[
              SizedBox(height: AppSpacing.section),
              _VeganuaryBlockView(
                block: block,
                seenCards: seenCards,
                onCardSeen: onCardSeen,
              ),
            ],
            if (info.sources.isNotEmpty) ...[
              SizedBox(height: AppSpacing.section),
              _VeganuarySources(sources: info.sources),
            ],
          ],
        ),
      ),
    );
  }
}

/// Numbered like the `[1]` of the text, each opening its link.
class _VeganuarySources extends StatelessWidget {
  final List<VeganuarySource> sources;

  const _VeganuarySources({required this.sources});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 24.h),
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        shape: squircleBorder(
          radius: 48.r,
          side: const BorderSide(color: kBorderDefault, width: 1.5),
        ),
      ),
      // The taps' ink above the box's color
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Text('Sources',
                  style:
                      AppTextStyles.bodyBold13.copyWith(color: kTextPrimary)),
            ),
            for (int i = 0; i < sources.length; i++)
              Semantics(
                link: true,
                label: 'Source ${i + 1} : ${sources[i].label}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () =>
                      openExternalUrl(context, Uri.parse(sources[i].url)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 66.w,
                          child: Text('[${i + 1}]',
                              style: AppTextStyles.bodyBold13
                                  .copyWith(color: primary)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sources[i].label,
                                  style: AppTextStyles.bodyRegular13
                                      .copyWith(color: kTextPrimary)),
                              Text(
                                Uri.parse(sources[i].url).host,
                                style: AppTextStyles.bodyRegular12
                                    .copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 24.w),
                        Icon(Icons.open_in_new_rounded,
                            color: primary, size: 48.sp),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VeganuaryBlockView extends StatelessWidget {
  final VeganuaryBlock block;
  final Set<GridItem> seenCards;
  final ValueChanged<GridItem>? onCardSeen;

  const _VeganuaryBlockView({
    required this.block,
    this.seenCards = const {},
    this.onCardSeen,
  });

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TextBlock(:final text) => VeganuaryRichText(text),
      BulletsBlock(:final items) => Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: AppSpacing.section),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: _bodyStyle),
                  SizedBox(width: 30.w),
                  Expanded(child: VeganuaryRichText(items[i])),
                ],
              ),
            ],
          ],
        ),
      ImageBlock(:final src, :final caption) => Column(
          children: [
            ClipSmoothRect(
              radius: squircleRadius(48.r),
              child: VeganuaryImage(src),
            ),
            if (caption != null) ...[
              SizedBox(height: 18.h),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyItalic12
                    .copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      CalloutBlock(:final text) => InfoBox(text: text),
      AppLinkBlock(:final label, :final target) =>
        _AppLink(label: label, target: target),
      GridBlock(:final columns, :final items) => _VeganuaryGrid(
          columns: columns,
          items: items,
          seenCards: seenCards,
          onCardSeen: onCardSeen,
        ),
    };
  }
}

/// A button opening a page of the app, e.g. the B12 reminder settings.
class _AppLink extends StatelessWidget {
  final String label;
  final AppLinkTarget target;

  const _AppLink({required this.label, required this.target});

  IconData get _icon => switch (target) {
        AppLinkTarget.b12Info => Icons.menu_book_rounded,
        AppLinkTarget.b12Reminder => Icons.notifications_active_outlined,
      };

  void _open(BuildContext context) {
    switch (target) {
      case AppLinkTarget.b12Info:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const B12InfoPage()),
        );
      case AppLinkTarget.b12Reminder:
        // Like from the settings and the dashboard's B12 banner
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const B12ReminderSettingsModal(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 39.h),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 48.r,
              side: const BorderSide(color: kBorderDefault, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(_icon, color: primary, size: 60.sp),
              SizedBox(width: 36.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyBold15.copyWith(color: kTextPrimary),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[500], size: 66.sp),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows of [columns] cards of the same height. Cards with details open them
/// in a dialog, then show a check; the first one pulses until one is read.
class _VeganuaryGrid extends StatelessWidget {
  final int columns;
  final List<GridItem> items;
  final Set<GridItem> seenCards;
  final ValueChanged<GridItem>? onCardSeen;

  const _VeganuaryGrid({
    required this.columns,
    required this.items,
    required this.seenCards,
    required this.onCardSeen,
  });

  Future<void> _open(BuildContext context, GridItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _GridDetailsDialog(item: item),
    );
    onCardSeen?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 30.w;
    final noneSeen = !items.any(seenCards.contains);
    Widget cardAt(int i) {
      final item = items[i];
      final card = _GridCard(
        item: item,
        horizontal: columns == 1,
        seen: seenCards.contains(item),
        onTap: item.details == null ? null : () => _open(context, item),
      );
      if (item.details == null) return card;
      // Shows the cards can be opened, as long as none was
      return AttentionPulse(
        enabled: noneSeen &&
            item == items.firstWhere((other) => other.details != null),
        radius: 48.r,
        color: Theme.of(context).colorScheme.primary,
        child: card,
      );
    }

    return Column(
      children: [
        for (int start = 0; start < items.length; start += columns) ...[
          if (start > 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = start; i < start + columns; i++) ...[
                  if (i > start) SizedBox(width: spacing),
                  Expanded(
                    // The last row keeps the cards' width
                    child:
                        i < items.length ? cardAt(i) : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final GridItem item;

  /// Image beside the text (a single column), for longer texts.
  final bool horizontal;

  /// Its details were read.
  final bool seen;

  /// Opens its details; null without any.
  final VoidCallback? onTap;

  const _GridCard({
    required this.item,
    required this.horizontal,
    required this.seen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = item.image == null
        ? null
        : AspectRatio(
            aspectRatio: 1,
            child: VeganuaryImage(item.image!, fit: BoxFit.contain),
          );
    final textAlign = horizontal ? TextAlign.start : TextAlign.center;
    final texts = [
      Text(
        item.label,
        textAlign: textAlign,
        style: AppTextStyles.bodyBold13.copyWith(color: kTextPrimary),
      ),
      if (item.text != null) ...[
        SizedBox(height: 6.h),
        VeganuaryRichText(
          item.text!,
          textAlign: textAlign,
          style: AppTextStyles.bodyRegular12
              .copyWith(color: Colors.grey[600], height: 1.3),
        ),
      ],
    ];

    final card = Container(
      padding: EdgeInsets.all(30.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 48.r,
          side: BorderSide(
            color: seen ? kAccentYellow : kBorderDefault,
            width: seen ? 2 : 1.5,
          ),
        ),
      ),
      child: horizontal
          ? Row(
              children: [
                if (image != null) ...[
                  SizedBox(width: 210.w, child: image),
                  SizedBox(width: 36.w),
                ],
                Expanded(
                  child: Column(
                    // Beside the image, when shorter than it
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: texts,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                if (image != null) ...[image, SizedBox(height: 18.h)],
                ...texts,
              ],
            ),
    );
    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: seen ? '${item.label}, lu' : item.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            card,
            // Like a day done on the path
            Positioned(
              top: 18.w,
              right: 18.w,
              child: AnimatedScale(
                scale: seen ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 54.w,
                  height: 54.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentYellow,
                  ),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 38.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid card's details, opened from it.
class _GridDetailsDialog extends StatelessWidget {
  final GridItem item;

  const _GridDetailsDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final details = item.details!;
    return Dialog(
      backgroundColor: Colors.white,
      shape: squircleBorder(radius: 28.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(48.w, 48.w, 48.w, 0),
              child: _SourcesScope(
                sources: details.sources,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(details.title,
                        style: AppTextStyles.baloo22,
                        textAlign: TextAlign.center),
                    for (final block in details.blocks) ...[
                      SizedBox(height: AppSpacing.item),
                      _VeganuaryBlockView(block: block),
                    ],
                    if (details.sources.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.item),
                      _VeganuarySources(sources: details.sources),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(48.w),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'J’ai compris',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The idées reçues to pick from.
class VeganuaryMythPicker extends StatelessWidget {
  final String title;
  final List<VeganuaryMyth> myths;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  /// Above the title: what kind of page it is.
  final Widget? tag;

  const VeganuaryMythPicker({
    super.key,
    required this.title,
    required this.myths,
    required this.selectedId,
    required this.onSelected,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal, vertical: 48.h),
      children: [
        ..._tagAbove(tag),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo26
              .copyWith(fontWeight: FontWeight.w700, height: 1.15),
        ),
        SizedBox(height: AppSpacing.section),
        for (final myth in myths) ...[
          _ChoiceOption(
            label: myth.label,
            highlight: myth.id == selectedId ? _ChoiceHighlight.picked : null,
            onTap: () => onSelected(myth.id),
          ),
          SizedBox(height: AppSpacing.item),
        ],
        // The pool is as big as the week: one a day, all done by its end
        SizedBox(height: AppSpacing.item),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 48.sp),
            SizedBox(width: 18.w),
            Expanded(
              child: Text(
                'Ne vous inquiétez pas, à la fin de la semaine vous les aurez '
                'toutes vues !',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A quiz question: once a choice is tapped, it shows in green, orange
/// (half right) or red, the right ones in green, then the explanation.
class VeganuaryQuizView extends StatelessWidget {
  final QuizStep quiz;

  /// Index of the choice picked, null until answered.
  final int? selected;

  /// Rereading a done day: [selected] is the right answer, shown without
  /// a verdict.
  final bool reviewing;
  final ValueChanged<int> onSelected;

  /// Above the question: what kind of page it is.
  final Widget? tag;

  const VeganuaryQuizView({
    super.key,
    required this.quiz,
    required this.selected,
    this.reviewing = false,
    required this.onSelected,
    this.tag,
  });

  _ChoiceHighlight? _highlightOf(int index) {
    if (selected == null) return null;
    final result = quiz.choices[index].result;
    if (index != selected && result != QuizResult.right) return null;
    return switch (result) {
      QuizResult.right => _ChoiceHighlight.right,
      QuizResult.partial => _ChoiceHighlight.partial,
      QuizResult.wrong => _ChoiceHighlight.wrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final picked =
        selected == null || reviewing ? null : _highlightOf(selected!);
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal, vertical: 48.h),
      children: [
        ..._tagAbove(tag),
        Text(
          quiz.question,
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo26
              .copyWith(fontWeight: FontWeight.w700, height: 1.15),
        ),
        SizedBox(height: AppSpacing.section),
        for (int i = 0; i < quiz.choices.length; i++) ...[
          _ChoiceOption(
            label: quiz.choices[i].text,
            highlight: _highlightOf(i),
            // Answered once
            onTap: selected == null ? () => onSelected(i) : null,
          ),
          SizedBox(height: AppSpacing.item),
        ],
        AnimatedReveal(
          visible: selected != null,
          child: Padding(
            padding: EdgeInsets.only(top: AppSpacing.item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (picked?.verdict != null) ...[
                  Text(
                    picked!.verdict!,
                    style:
                        AppTextStyles.bodyBold15.copyWith(color: picked.color),
                  ),
                  SizedBox(height: 18.h),
                ],
                VeganuaryRichText(quiz.explanation),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _ChoiceHighlight {
  /// An idée reçue picked
  picked(kAccentYellow, Icons.check_rounded, null),
  right(kSemanticSuccess, Icons.check_rounded, 'Bonne réponse !'),
  partial(kSemanticWarning, Icons.remove_rounded, 'Presque !'),
  wrong(kSemanticError, Icons.close_rounded, 'Pas tout à fait…');

  final Color color;
  final IconData icon;

  /// Above a quiz's explanation, for the answer picked.
  final String? verdict;

  const _ChoiceHighlight(this.color, this.icon, this.verdict);

  Color get background =>
      this == picked ? kSecondaryTag : color.withValues(alpha: 0.1);
}

/// An idée reçue to pick, or a quiz answer.
class _ChoiceOption extends StatelessWidget {
  final String label;

  /// Null: not picked (nor the right answer).
  final _ChoiceHighlight? highlight;

  /// Null once it can't be picked anymore.
  final VoidCallback? onTap;

  const _ChoiceOption({
    required this.label,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = this.highlight;
    final selected = highlight != null;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 51.w, vertical: 54.h),
          decoration: ShapeDecoration(
            color: highlight?.background ?? Colors.white.withValues(alpha: 0.6),
            shape: squircleBorder(
              radius: 48.r,
              side: BorderSide(
                color: highlight?.color ?? kBorderDefault,
                width: selected ? 2 : 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 66.w,
                height: 66.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlight?.color ?? Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(color: kBorderDefault, width: 2),
                ),
                child: selected
                    ? Icon(highlight.icon, color: Colors.white, size: 46.sp)
                    : null,
              ),
              SizedBox(width: 39.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyRegular15
                      .copyWith(color: highlight?.color ?? kTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week's recipe. The user won't necessarily cook it right now, so
/// it's offered to download as an image (through the share sheet, which
/// can save it to the photos), like the vegan anniversary card.
class VeganuaryRecipeView extends StatefulWidget {
  final RecipeStep recipe;

  /// At the top (not in the downloaded image): what kind of page it is.
  final Widget? tag;

  const VeganuaryRecipeView({super.key, required this.recipe, this.tag});

  @override
  State<VeganuaryRecipeView> createState() => _VeganuaryRecipeViewState();
}

class _VeganuaryRecipeViewState extends State<VeganuaryRecipeView> {
  // Wraps the recipe (not the download invitation) so it can be captured
  // to an image identical to what's shown. In a SingleChildScrollView, not
  // a ListView, so the parts scrolled out are laid out and captured too.
  final GlobalKey _recipeKey = GlobalKey();
  bool _downloading = false;

  RecipeStep get recipe => widget.recipe;

  /// Render the recipe [RepaintBoundary] to a PNG file in the temp dir.
  Future<File?> _capturedRecipeFile() async {
    final boundary =
        _recipeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/recette-veganuary.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _download(BuildContext buttonContext) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final file = await _capturedRecipeFile();
      if (file == null || !buttonContext.mounted) return;

      // sharePositionOrigin is required for the iPad popover.
      final box = buttonContext.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${recipe.title} : la recette du Veganuary de 321 Vegan 🌱 '
            'https://321vegan.fr',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 24.h, bottom: 48.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._tagAbove(widget.tag),
                _buildDownloadInvitation(),
              ],
            ),
          ),
          RepaintBoundary(
            key: _recipeKey,
            // Opaque, for the image not to come out transparent
            child: ColoredBox(
              color: kBackgroundGradientBottom,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
                child: _buildRecipe(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadInvitation() {
    return Container(
      padding: EdgeInsets.all(45.w),
      decoration: ShapeDecoration(
        color: kSecondaryTag,
        shape: squircleBorder(
          radius: 48.r,
          side: const BorderSide(color: kAccentYellow),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pas le temps de cuisiner aujourd’hui ? Gardez la recette '
              'pour plus tard.',
              style: AppTextStyles.bodyMedium13.copyWith(color: kTextPrimary),
            ),
          ),
          SizedBox(width: 30.w),
          // Own context: the share popover (iPad) points at the button
          Builder(
            builder: (buttonContext) => AppButton(
              label: 'Télécharger',
              icon: Icons.download_rounded,
              compact: true,
              isLoading: _downloading,
              backgroundColor: kAccentYellow,
              disabledBackgroundColor: kAccentYellow,
              onPressed: () => _download(buttonContext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipe(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recipe.image != null)
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: ClipSmoothRect(
              radius: squircleRadius(48.r),
              child: VeganuaryImage(recipe.image!, height: 600.h),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recipe.image != null) SizedBox(height: AppSpacing.section),
              Text(
                'La recette végane de la semaine !',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo22.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: AppSpacing.afterTitle),
              Text(
                recipe.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo36,
              ),
              SizedBox(height: AppSpacing.section),
              Text(
                recipe.servings == null
                    ? 'Ingrédients'
                    : 'Ingrédients pour ${recipe.servings}',
                style: AppTextStyles.baloo22,
              ),
              SizedBox(height: AppSpacing.afterTitle),
              for (final group in recipe.ingredients) ...[
                if (group.title != null)
                  Padding(
                    padding: EdgeInsets.only(top: 18.h, bottom: 18.h),
                    child: Text(
                      group.title!,
                      style: AppTextStyles.bodyBold15
                          .copyWith(color: kTextPrimary),
                    ),
                  ),
                for (final ingredient in group.items)
                  Padding(
                    padding: EdgeInsets.only(bottom: 18.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: _bodyStyle),
                        SizedBox(width: 30.w),
                        Expanded(child: VeganuaryRichText(ingredient)),
                      ],
                    ),
                  ),
              ],
              SizedBox(height: AppSpacing.section),
              Text('Étapes', style: AppTextStyles.baloo22),
              SizedBox(height: AppSpacing.afterTitle),
              for (int i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.item),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60.w,
                        child: Text(
                          '${i + 1}.',
                          style: _bodyStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      Expanded(child: VeganuaryRichText(recipe.steps[i])),
                    ],
                  ),
                ),
              // Where the downloaded image comes from
              SizedBox(height: AppSpacing.afterTitle),
              Text(
                'Recette du Veganuary · 321 Vegan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyRegular12
                    .copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown once a day is done for the first time: its number, big, and the
/// days of the week ticked so far. Once the whole week is done, its badge
/// instead of the usual illustration.
class VeganuaryDoneView extends StatelessWidget {
  final int day;

  /// Numbers of the days of the week, in order.
  final List<int> weekDays;
  final Set<int> completedDays;

  /// The next day is already open (days missed to catch up).
  final bool nextAvailable;

  /// Illustration of the week's badge (a placeholder when null).
  final String? badgeImage;

  const VeganuaryDoneView({
    super.key,
    required this.day,
    required this.weekDays,
    required this.completedDays,
    required this.nextAvailable,
    this.badgeImage,
  });

  bool get _weekCompleted => weekDays.every(completedDays.contains);

  @override
  Widget build(BuildContext context) {
    final isLastDay = day >= VeganuaryService.totalDays;
    final message = isLastDay
        ? 'Bravo, vous avez parcouru les ${VeganuaryService.totalDays} '
            'jours du Veganuary !'
        : _weekCompleted
            ? 'Vous avez été là jour après jour, et ça paie : vous en savez '
                'maintenant beaucoup plus.\nContinuez comme ça !'
            : nextAvailable
                ? 'Leçon terminée, bien joué ! 🎉\nVous rattrapez votre '
                    'retard : le jour ${day + 1} vous attend déjà.'
                : 'Leçon terminée, bien joué ! 🎉\nVous êtes allé·e '
                    'jusqu’au bout aujourd’hui. Rendez-vous demain pour la '
                    'suite.';
    final yellowTitle =
        AppTextStyles.baloo30Bold.copyWith(color: kAccentYellow);
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VeganuaryImage(
            _weekCompleted
                ? badgeImage ?? 'lib/assets/images/characters/tomatoes.webp'
                : 'lib/assets/images/characters/avocado.webp',
            height: 480.h,
            fit: BoxFit.contain,
          ),
          SizedBox(height: AppSpacing.section),
          Text(
            '$day',
            style: AppTextStyles.baloo90.copyWith(color: kAccentYellow),
          ),
          Text(day > 1 ? 'jours !' : 'jour !', style: yellowTitle),
          if (_weekCompleted) ...[
            SizedBox(height: AppSpacing.section),
            Text('Badge débloqué !',
                textAlign: TextAlign.center, style: yellowTitle),
          ],
          SizedBox(height: AppSpacing.section),
          Text(message, textAlign: TextAlign.center, style: _bodyStyle),
          SizedBox(height: AppSpacing.section * 1.5),
          // Shrinks rather than overflowing on a narrow screen
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                for (final weekDay in weekDays)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: _WeekDayDot(
                      day: weekDay,
                      done: completedDays.contains(weekDay),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayDot extends StatelessWidget {
  final int day;
  final bool done;

  const _WeekDayDot({required this.day, required this.done});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jour $day${done ? ', terminé' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$day',
            style: AppTextStyles.bodyBold13
                .copyWith(color: done ? kAccentYellow : Colors.grey[500]),
          ),
          SizedBox(height: 18.h),
          Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? kAccentYellow : kLockedFill,
            ),
            child: done
                ? Icon(Icons.check_rounded, color: Colors.white, size: 50.sp)
                : null,
          ),
        ],
      ),
    );
  }
}

/// "Ce que vous avez appris aujourd'hui", the last page of a day.
class VeganuaryRecapView extends StatelessWidget {
  final List<VeganuaryRecapCard> cards;

  /// Above the title: what kind of page it is.
  final Widget? tag;

  const VeganuaryRecapView({super.key, required this.cards, this.tag});

  @override
  Widget build(BuildContext context) {
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._tagAbove(tag),
          Text(
            'Récapitulatif du jour',
            textAlign: TextAlign.center,
            // Figma: line-height 38
            style: AppTextStyles.baloo36.copyWith(height: 38 / 36),
          ),
          for (final card in cards) ...[
            SizedBox(height: AppSpacing.section),
            VeganuaryRecapCardView(card: card),
          ],
        ],
      ),
    );
  }
}

/// A card of "Ce que vous avez appris" (end of a day, fiches récap' of a
/// week).
class VeganuaryRecapCardView extends StatelessWidget {
  final VeganuaryRecapCard card;

  const VeganuaryRecapCardView({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final iconSize = 120.w;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 51.w, vertical: 60.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 60.r,
          side: const BorderSide(color: kBorderDefault, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          if (card.image != null)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: VeganuaryImage(card.image!, fit: BoxFit.contain),
            )
          else if (card.emoji != null)
            SizedBox(
              width: iconSize,
              child: Text(
                card.emoji!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 96.sp),
              ),
            ),
          SizedBox(width: 51.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: AppTextStyles.baloo22),
                SizedBox(height: 30.h),
                for (final bullet in card.bullets)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: _bodyStyle),
                      Expanded(child: VeganuaryRichText(bullet)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
