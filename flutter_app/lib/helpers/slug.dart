const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', 'ñ': 'n', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', //
  'œ': 'oe', 'æ': 'ae',
};

/// "Mes restos à Lyon !" → "mes-restos-a-lyon": lowercase words without
/// accents, joined by dashes (emojis and other scripts dropped), for a
/// link or a file name.
String slugify(String text) => text
    .toLowerCase()
    .split('')
    .map((c) => _accents[c] ?? c)
    .join()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
