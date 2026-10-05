import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains("'nutriguard1/web/icons/1.png'")) {
      content = content.replaceAll(
        "'nutriguard1/web/icons/1.png'",
        "'web/icons/1.png'",
      );
      file.writeAsStringSync(content);
    }
  }
}
