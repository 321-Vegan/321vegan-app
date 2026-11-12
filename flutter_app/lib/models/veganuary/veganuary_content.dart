/// Content of the Veganuary course (31 days: 4 weeks of 7 days + 1 of 3),
/// read from one JSON file per week in lib/assets/veganuary/. A day is a
/// list of steps (pages shown one after the other: maybe a quiz, info pages,
/// an idée reçue, sometimes a recipe); each step type has its
/// own JSON shape, see [VeganuaryStep.fromJson].
class VeganuaryWeek {
  final int number;
  final String title;

  /// Asset shown next to the week title (e.g. the strawberry of week 1).
  final String? illustration;

  /// Assets in the bends of the path, beside the days, one every three
  /// days on alternating sides.
  final List<String> pathIllustrations;

  /// Illustration of the badge earned once the week is done.
  final String? badgeImage;

  /// Banner of the week's card in the list of weeks.
  final String? coverImage;

  /// Idées reçues of the week: each day the user picks one not answered
  /// yet, so the pool is as big as the week and all get done by its end.
  final List<VeganuaryMyth> myths;
  final List<VeganuaryDay> days;

  const VeganuaryWeek({
    required this.number,
    required this.title,
    this.illustration,
    this.pathIllustrations = const [],
    this.badgeImage,
    this.coverImage,
    required this.myths,
    required this.days,
  });

  factory VeganuaryWeek.fromJson(Map<String, dynamic> json) {
    return VeganuaryWeek(
      number: json['number'] as int,
      title: json['title'] as String,
      illustration: json['illustration'] as String?,
      pathIllustrations:
          List<String>.from(json['path_illustrations'] as List? ?? const []),
      badgeImage: json['badge_image'] as String?,
      coverImage: json['cover_image'] as String?,
      myths: [
        for (final myth in json['myths'] as List? ?? const [])
          VeganuaryMyth.fromJson(myth as Map<String, dynamic>),
      ],
      days: [
        for (final day in json['days'] as List)
          VeganuaryDay.fromJson(day as Map<String, dynamic>),
      ],
    );
  }

  VeganuaryMyth? mythById(String id) {
    for (final myth in myths) {
      if (myth.id == id) return myth;
    }
    return null;
  }
}

/// Icon of a day's node on the path, after the day's theme (`"icon":
/// "cart"`); add one here and in the node for a new theme.
enum VeganuaryDayIcon { info, myth, recipe, book, cart }

class VeganuaryDay {
  /// Number in the whole course (1 to 31), not in the week.
  final int number;
  final VeganuaryDayIcon icon;
  final List<VeganuaryStep> steps;

  /// Last page
  final List<VeganuaryRecapCard> recap;

  const VeganuaryDay({
    required this.number,
    required this.icon,
    required this.steps,
    this.recap = const [],
  });

  factory VeganuaryDay.fromJson(Map<String, dynamic> json) {
    final steps = [
      for (final step in json['steps'] as List)
        VeganuaryStep.fromJson(step as Map<String, dynamic>),
    ];
    final iconName = json['icon'] as String?;
    return VeganuaryDay(
      number: json['number'] as int,
      icon: VeganuaryDayIcon.values
              .where((icon) => icon.name == iconName)
              .firstOrNull ??
          VeganuaryDayIcon.info,
      steps: steps,
      recap: [
        for (final card in json['recap'] as List? ?? const [])
          VeganuaryRecapCard.fromJson(card as Map<String, dynamic>),
      ],
    );
  }
}

/// `{"emoji": "🍯", "title": ..., "bullets": [...]}`; `image` (asset path
/// or URL) instead of `emoji` for an illustration.
class VeganuaryRecapCard {
  final String? emoji;
  final String? image;
  final String title;
  final List<String> bullets;

  const VeganuaryRecapCard({
    this.emoji,
    this.image,
    required this.title,
    required this.bullets,
  });

  factory VeganuaryRecapCard.fromJson(Map<String, dynamic> json) {
    return VeganuaryRecapCard(
      emoji: json['emoji'] as String?,
      image: json['image'] as String?,
      title: json['title'] as String,
      bullets: List<String>.from(json['bullets'] as List? ?? const []),
    );
  }
}

/// One page of a day.
sealed class VeganuaryStep {
  const VeganuaryStep();

  factory VeganuaryStep.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'info':
        return InfoStep(VeganuaryInfo.fromJson(json));
      case 'myth':
        return MythStep(title: json['title'] as String?);
      case 'recipe':
        return RecipeStep.fromJson(json);
      case 'quiz':
        return QuizStep.fromJson(json);
    }
    throw FormatException('Unknown Veganuary step type: ${json['type']}');
  }
}

/// `{"type": "quiz", "question": ..., "choices": [{"text": ...,
/// "result": "right"}, {"text": ..., "result": "partial"}, {"text": ...}],
/// "explanation": ...}`: one question, answered once. Put before the info
/// pages it leads to.
class QuizStep extends VeganuaryStep {
  final String question;
  final List<QuizChoice> choices;

  /// Shown once answered, whatever the answer; `**text**` is bold.
  final String explanation;

  const QuizStep({
    required this.question,
    required this.choices,
    required this.explanation,
  });

  factory QuizStep.fromJson(Map<String, dynamic> json) {
    return QuizStep(
      question: json['question'] as String,
      choices: [
        for (final choice in json['choices'] as List)
          QuizChoice.fromJson(choice as Map<String, dynamic>),
      ],
      explanation: json['explanation'] as String,
    );
  }
}

/// `"result"`: "right", "partial" (half right) or "wrong" (when absent).
enum QuizResult { right, partial, wrong }

class QuizChoice {
  final String text;
  final QuizResult result;

  const QuizChoice({required this.text, required this.result});

  factory QuizChoice.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as String? ?? 'wrong';
    return QuizChoice(
      text: json['text'] as String,
      result: QuizResult.values.firstWhere(
        (value) => value.name == result,
        orElse: () =>
            throw FormatException('Unknown Veganuary quiz result: $result'),
      ),
    );
  }
}

/// `{"type": "info", "title": ..., "blocks": [...]}`
class InfoStep extends VeganuaryStep {
  final VeganuaryInfo info;

  const InfoStep(this.info);
}

/// `{"type": "myth"}`: the user picks an idée reçue of the week's pool,
/// then reads its answer (two pages).
class MythStep extends VeganuaryStep {
  /// Question above the choices; a default one when null.
  final String? title;

  const MythStep({this.title});
}

/// `{"type": "recipe", "title": ..., "image": ..., "servings": 2,
/// "ingredients": [...], "steps": [...]}`. `servings` can be a number of
/// people or a text ("une tarte"); `ingredients`, plain lines, or groups
/// `{"title": "Pour la pâte", "items": [...]}` (both can be mixed).
class RecipeStep extends VeganuaryStep {
  final String title;

  /// Asset path or URL.
  final String? image;

  /// After "Ingrédients pour" ("2 personnes", "une tarte"), if given.
  final String? servings;
  final List<RecipeIngredients> ingredients;
  final List<String> steps;

  const RecipeStep({
    required this.title,
    this.image,
    this.servings,
    required this.ingredients,
    required this.steps,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    final servings = json['servings'];
    // Lines in a row make a group without a title
    final ingredients = <RecipeIngredients>[];
    var lines = <String>[];
    void addLines() {
      if (lines.isEmpty) return;
      ingredients.add(RecipeIngredients(items: lines));
      lines = [];
    }

    for (final entry in json['ingredients'] as List) {
      if (entry is String) {
        lines.add(entry);
      } else {
        addLines();
        ingredients
            .add(RecipeIngredients.fromJson(entry as Map<String, dynamic>));
      }
    }
    addLines();
    return RecipeStep(
      title: json['title'] as String,
      image: json['image'] as String?,
      servings: switch (servings) {
        int people => '$people personne${people > 1 ? 's' : ''}',
        String text => text,
        _ => null,
      },
      ingredients: ingredients,
      steps: List<String>.from(json['steps'] as List),
    );
  }
}

class RecipeIngredients {
  /// "Pour la pâte"; null for lines given without a group.
  final String? title;
  final List<String> items;

  const RecipeIngredients({this.title, required this.items});

  factory RecipeIngredients.fromJson(Map<String, dynamic> json) {
    return RecipeIngredients(
      title: json['title'] as String?,
      items: List<String>.from(json['items'] as List),
    );
  }
}

/// An info page (or a myth's answer): a title, then blocks shown one under
/// the other, see [VeganuaryBlock.fromJson], then its sources, if any.
class VeganuaryInfo {
  final String title;
  final List<VeganuaryBlock> blocks;

  /// Listed under the blocks, numbered from 1: `[1]` in a text or bullet
  /// refers to the first one.
  final List<VeganuarySource> sources;

  const VeganuaryInfo({
    required this.title,
    required this.blocks,
    this.sources = const [],
  });

  /// Grid cards with details: all to open before going on.
  Iterable<GridItem> get cardsToOpen => blocks
      .whereType<GridBlock>()
      .expand((grid) => grid.items)
      .where((item) => item.details != null);

  factory VeganuaryInfo.fromJson(Map<String, dynamic> json) {
    return VeganuaryInfo(
      title: json['title'] as String,
      blocks: [
        for (final block in json['blocks'] as List? ?? const [])
          VeganuaryBlock.fromJson(block as Map<String, dynamic>),
      ],
      sources: [
        for (final source in json['sources'] as List? ?? const [])
          VeganuarySource.fromJson(source as Map<String, dynamic>),
      ],
    );
  }
}

/// `{"label": "Reed et al., Reproductive Toxicology, 2021", "url": ...}`
class VeganuarySource {
  final String label;
  final String url;

  const VeganuarySource({required this.label, required this.url});

  factory VeganuarySource.fromJson(Map<String, dynamic> json) {
    return VeganuarySource(
      label: json['label'] as String,
      url: json['url'] as String,
    );
  }
}

/// A piece of an info page. In text and bullets, `**text**` is bold.
sealed class VeganuaryBlock {
  const VeganuaryBlock();

  factory VeganuaryBlock.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextBlock(json['text'] as String);
      case 'bullets':
        return BulletsBlock(List<String>.from(json['items'] as List));
      case 'image':
        return ImageBlock(
          src: json['src'] as String,
          caption: json['caption'] as String?,
        );
      case 'callout':
        return CalloutBlock(json['text'] as String);
      case 'app_link':
        final target = json['target'] as String;
        return AppLinkBlock(
          label: json['label'] as String,
          target: AppLinkTarget.values.firstWhere(
            (value) => value.json == target,
            orElse: () =>
                throw FormatException('Unknown Veganuary link target: $target'),
          ),
        );
      case 'grid':
        return GridBlock(
          columns: json['columns'] as int? ?? 2,
          items: [
            for (final item in json['items'] as List)
              GridItem.fromJson(item as Map<String, dynamic>),
          ],
        );
    }
    throw FormatException('Unknown Veganuary block type: ${json['type']}');
  }
}

/// `{"type": "text", "text": ...}`: a paragraph.
class TextBlock extends VeganuaryBlock {
  final String text;

  const TextBlock(this.text);
}

/// `{"type": "bullets", "items": [...]}`
class BulletsBlock extends VeganuaryBlock {
  final List<String> items;

  const BulletsBlock(this.items);
}

/// `{"type": "image", "src": ..., "caption": ...}`: [src] is an asset path
/// or a URL.
class ImageBlock extends VeganuaryBlock {
  final String src;
  final String? caption;

  const ImageBlock({required this.src, this.caption});
}

/// `{"type": "callout", "text": ...}`: a highlighted box (tip, source...),
/// plain text.
class CalloutBlock extends VeganuaryBlock {
  final String text;

  const CalloutBlock(this.text);
}

/// `{"type": "app_link", "label": "Tout savoir sur la B12", "target":
/// "b12_info"}`: a button opening a page of the app.
class AppLinkBlock extends VeganuaryBlock {
  final String label;
  final AppLinkTarget target;

  const AppLinkBlock({required this.label, required this.target});
}

/// Pages of the app a link can open; add one here (and where the link
/// opens it, in the step views) for a new one.
enum AppLinkTarget {
  /// The B12 explanations ("Plus d'informations").
  b12Info('b12_info'),

  /// The B12 reminder settings.
  b12Reminder('b12_reminder');

  /// Its name in the JSON.
  final String json;

  const AppLinkTarget(this.json);
}

/// `{"type": "grid", "columns": 2, "items": [{"image": ..., "label":
/// "Conserves", "text": "Pois chiches, lentilles…"}]}`: cards side by side
/// (2 columns when absent), e.g. what to have in the cupboard. With 1
/// column, a list: each image beside its text, for longer texts.
class GridBlock extends VeganuaryBlock {
  final int columns;
  final List<GridItem> items;

  const GridBlock({required this.columns, required this.items});
}

class GridItem {
  /// Asset path or URL; none: just the label and text.
  final String? image;
  final String label;

  /// Under the label, smaller; `**text**` is bold.
  final String? text;

  /// `"details": {"title": ..., "blocks": [...], "sources": [...]}`: the
  /// card opens them in a dialog (the title defaults to the label), and is
  /// checked once they were read.
  final VeganuaryInfo? details;

  const GridItem({this.image, required this.label, this.text, this.details});

  factory GridItem.fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String;
    final details = json['details'] as Map<String, dynamic>?;
    return GridItem(
      image: json['image'] as String?,
      label: label,
      text: json['text'] as String?,
      details: details == null
          ? null
          : VeganuaryInfo.fromJson({'title': label, ...details}),
    );
  }
}

/// `{"id": ..., "label": ..., "answer": {"title": ..., "blocks": [...]},
/// "recap": {...}}`
class VeganuaryMyth {
  /// Saved in the progress: never change it once released.
  final String id;

  /// What the user picks from ("Les végans sont carencés").
  final String label;
  final VeganuaryInfo answer;

  /// Added to the recap of the day it's picked.
  final VeganuaryRecapCard? recap;

  const VeganuaryMyth({
    required this.id,
    required this.label,
    required this.answer,
    this.recap,
  });

  factory VeganuaryMyth.fromJson(Map<String, dynamic> json) {
    final recap = json['recap'] as Map<String, dynamic>?;
    return VeganuaryMyth(
      id: json['id'] as String,
      label: json['label'] as String,
      answer: VeganuaryInfo.fromJson(json['answer'] as Map<String, dynamic>),
      recap: recap == null ? null : VeganuaryRecapCard.fromJson(recap),
    );
  }
}
