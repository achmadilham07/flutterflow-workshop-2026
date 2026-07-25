library;

/// Phase A of the main -> baseline-starter reset. Split from phase B
/// because renaming the struct field and then referencing the new name in
/// the same push fails: the DSL's `res['places']` accessor resolves against
/// the locally generated `ff.Structs` snapshot (stale at compile time), not
/// the in-memory renamed field from `app.raw` in this same run. Phase B
/// (DetailPage/FavoritesPage revert) runs after a context refresh.
///
/// This phase:
/// 1. Reintroduces the Segmen 1 bug (`PlaceDetailResponse.place` -> `.places`).
/// 2. Rebinds PlaceCard's Text widgets back to plain Param values, removes
///    the 2 remaining custom functions.
/// 3. Removes the Firestore `favorites` collection.
/// 4. Re-breaks HomePage's PlaceCard navigation.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildResetA,
      apiKey: options.apiKey,
      baseUrl: options.baseUrl,
      projectId: options.projectId,
      dryRun: options.dryRun,
      commitMessage: options.commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

final class _CliOptions {
  const _CliOptions({this.apiKey, this.baseUrl, this.projectId, this.dryRun = false, this.commitMessage});
  final String? apiKey;
  final String? baseUrl;
  final String? projectId;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey, baseUrl, projectId, commitMessage;
  var dryRun = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--api-key':
        apiKey = args[++i];
      case '--base-url':
        baseUrl = args[++i];
      case '--project-id':
        projectId = args[++i];
      case '--commit-message':
        commitMessage = args[++i];
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: ${args[i]}');
        exit(64);
    }
  }
  return _CliOptions(
    apiKey: apiKey,
    baseUrl: baseUrl,
    projectId: projectId,
    dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

void buildResetA(App app) {
  // 1. Reintroduce the Segmen 1 bug.
  app.raw((project) {
    final structs = project.ensureBackend().ensureDataSchemaConfig().dataStructs;
    final detailResponse = structs.firstWhere(
      (s) => s.identifier.name == 'PlaceDetailResponse',
    );
    final field = detailResponse.fields.firstWhere(
      (f) => f.identifier.name == 'place',
    );
    field.identifier.name = 'places';
  });

  // 2. Rebind PlaceCard's Text widgets back to plain Param values, then
  //    remove the 2 remaining custom functions.
  app.editComponent(ff.Components.placeCard, (component) {
    component.bindText(
      component.findByKey('Text_aufx6gdr'),
      Param(ff.Components.placeCard.params.placeDescription),
    );
    component.bindText(
      component.findByKey('Text_pmd4s253'),
      Param(ff.Components.placeCard.params.placeLike),
    );
  });
  app.removeCustomFunction('truncateDescription');
  app.removeCustomFunction('formatLikeCount');

  // NOTE: the `favorites` collection is still referenced by DetailPage's
  // onLoad Backend Query, the ToggleIcon's create/delete actions, and
  // FavoritesPage's ListView — removing it here fails validation. It's
  // removed in phase C, after phase B strips all of those references.

  // 4. Re-break HomePage's PlaceCard navigation (clear the onTapAction
  //    argument on the ComponentInstance node so it compiles to a no-op
  //    again, matching baseline-starter's un-fixed behavior).
  app.raw((project) {
    final page = findPage(project, name: 'HomePage')!;
    final instanceNode = findByKey(page.node, 'Container_sx4d1mel');
    if (instanceNode == null) {
      throw StateError('HomePage PlaceCard instance node not found.');
    }
    instanceNode.triggerActions.clear();
    final pass = instanceNode.parameterValues.parameterPasses['1tnq0roe'];
    if (pass != null) {
      pass.clearAction();
    }
  });
}
