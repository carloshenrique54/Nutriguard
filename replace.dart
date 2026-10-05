import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('Icons.apple')) {
      content = content.replaceAll(
        'const Icon(Icons.apple, color: Color(0xFFC23147), size: 32)',
        "Image.asset('web/icons/1.png', width: 32, height: 32)",
      );
      content = content.replaceAll(
        'const Icon(Icons.apple, color: Color(0xFFC23147), size: 40)',
        "Image.asset('web/icons/1.png', width: 40, height: 40)",
      );
      content = content.replaceAll(
        'Icons.apple, // Fallback visual se a imagem não for encontrada',
        "'web/icons/1.png', // Fallback visual se a imagem não for encontrada",
      );
      file.writeAsStringSync(content);
    }
  }
}
