library;

/// Phase D of the main -> baseline-starter reset (see phases A/B/C).
///
/// Phase A's attempt to re-break HomePage's PlaceCard navigation targeted
/// the wrong field: `node.parameterValues.parameterPasses['1tnq0roe']` (the
/// `onTapAction` component-param entry) was already unset — the actual
/// working navigation lives on `node.triggerActions`, a separate top-level
/// field set directly on the ComponentInstance node by the earlier manual
/// `ProjectComponentHandle`/`ComponentInstance` workaround (bypassing the
/// normal param-typed compilation path entirely, per `dsl/edit.dart`'s
/// `buildFixHomePage`). Clearing that list removes the compiled
/// `context.pushNamed(...)` call, restoring baseline-starter's "tap does
/// nothing" behavior.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildResetD,
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

void buildResetD(App app) {
  app.raw((project) {
    final page = findPage(project, name: 'HomePage')!;
    final instanceNode = findByKey(page.node, 'Container_sx4d1mel');
    if (instanceNode == null) {
      throw StateError('HomePage PlaceCard instance node not found.');
    }
    instanceNode.triggerActions.clear();
  });
}
