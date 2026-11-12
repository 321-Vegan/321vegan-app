/// Content of the Veganuary course (31 days: 4 weeks of 7 days + 1 of 3),
/// read from one JSON file per week in lib/assets/veganuary/. A day is a
/// list of steps (pages shown one after the other); each step type has its
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

/// Icon of a day's node on the path.
enum VeganuaryDayIcon { info, myth, recipe, book }

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
    }
    throw FormatException('Unknown Veganuary step type: ${json['type']}');
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
/// "ingredients": [...], "steps": [...]}`
class RecipeStep extends VeganuaryStep {
  final String title;

  /// Asset path or URL.
  final String? image;
  final int servings;
  final List<String> ingredients;
  final List<String> steps;

  const RecipeStep({
    required this.title,
    this.image,
    required this.servings,
    required this.ingredients,
    required this.steps,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      title: json['title'] as String,
      image: json['image'] as String?,
      servings: json['servings'] as int,
      ingredients: List<String>.from(json['ingredients'] as List),
      steps: List<String>.from(json['steps'] as List),
    );
  }
}

/// An info page (or a myth's answer): a title, then blocks shown one under
/// the other, see [VeganuaryBlock.fromJson].
class VeganuaryInfo {
  final String title;
  final List<VeganuaryBlock> blocks;

  const VeganuaryInfo({required this.title, required this.blocks});

  factory VeganuaryInfo.fromJson(Map<String, dynamic> json) {
    return VeganuaryInfo(
      title: json['title'] as String,
      blocks: [
        for (final block in json['blocks'] as List? ?? const [])
          VeganuaryBlock.fromJson(block as Map<String, dynamic>),
      ],
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
