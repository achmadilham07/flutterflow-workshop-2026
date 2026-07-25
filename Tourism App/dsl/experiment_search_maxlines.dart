library;

/// EXPERIMENTAL — baseline-starter branch only. Do NOT merge to main.
///
/// SearchPage's TextField never had `maxLines` set, so Flutter defaulted it
/// to a newline-capable field: pressing Enter inserted a line break instead
/// of firing `onFieldSubmitted` (the search never triggered). Setting
/// `maxLines: 1` makes it a single-line field, so Enter submits as expected.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildSearchMaxLinesFix,
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

void buildSearchMaxLinesFix(App app) {
  // The typed `EditWidgetPatch.maxLines(...)` helper only supports `Text`
  // widgets, not `TextField` — it throws "maxLines patches are only
  // supported for Text widgets, not TextField." So this drops into the raw
  // node-mutation escape hatch instead.
  app.editPage(ff.Pages.searchPage, (page) {
    page.mutateNode(
      ff.Pages.searchPage.widgets.byPath('SearchPage.body[0].children[0].children[0]').single,
      (node) {
        node.props.textField.maxLinesValue = FFIntegerValue(inputValue: 1);
      },
    );
  });
}
