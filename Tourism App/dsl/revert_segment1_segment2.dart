library;

/// Reverts manual rehearsal edits found on main so Segmen 1 and Segmen 2
/// have a clean "before" state again for the live demo:
///
/// 1. Renames `PlaceDetailResponse.place` back to `.places` (reintroduces
///    the intentional key-mismatch bug — the real endpoint returns `place`,
///    not `places`).
/// 2. Rebinds PlaceCard's description/like Text widgets back to plain
///    parameter values (removes the truncateDescription/formatLikeCount
///    custom-function bindings applied during rehearsal).
/// 3. Removes the 3 custom functions (truncateDescription, formatLikeCount,
///    formatDistance) so Segmen 2 starts from an empty Custom Functions
///    panel again.
///
/// Step 1 is intentionally NOT paired with a DetailPage onLoad fix in this
/// same script — the typed SDK snapshot used to compile this run still
/// reflects the OLD field name, so `res['places']` would fail to resolve
/// against it. That follow-up runs separately after a context refresh.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildRevert,
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

void buildRevert(App app) {
  // 1. Reintroduce the Segmen 1 bug: rename the struct field back.
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

  // 2. Rebind PlaceCard's Text widgets back to plain Param values.
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

  // 3. Remove the 3 custom functions.
  app.removeCustomFunction('truncateDescription');
  app.removeCustomFunction('formatLikeCount');
  app.removeCustomFunction('formatDistance');
}
