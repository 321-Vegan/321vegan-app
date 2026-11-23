import 'dart:io';

/// A local copy of the course's weeks (git-ignored: the content is only on
/// the API), in order: weekN.json files downloaded from the admin tool into
/// lib/assets/veganuary/, to check them with the tests. Usually none.
List<String> veganuaryWeekFiles() {
  final folder = Directory('lib/assets/veganuary');
  if (!folder.existsSync()) return const [];
  final files = folder
      .listSync()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => RegExp(r'week\d+\.json$').hasMatch(path))
      .toList();
  int number(String path) =>
      int.parse(RegExp(r'week(\d+)\.json$').firstMatch(path)!.group(1)!);
  return files..sort((a, b) => number(a).compareTo(number(b)));
}
