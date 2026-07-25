import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:test/test.dart';

import '../dsl/create.dart' as starter;

void main() {
  test('tourism app DSL compiles', () {
    final app = buildApp(starter.buildTourismApp);
    final project = compileApp(app).project;

    for (final name in [
      'HomePage',
      'DetailPage',
      'SearchPage',
      'FavoritesPage',
    ]) {
      final page = findPage(project, name: name);
      expect(page, isNotNull, reason: '$name should exist');
      expect(page!.node.type, FFWidgetType.Scaffold);
    }
  });
}
