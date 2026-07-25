library;

/// Reorders the bottom nav to Home, Search, Favorites (left to right).
///
/// It ended up as Search, Favorites, Home because Search and Favorites were
/// already in the nav bar from the very first create push, and HomePage was
/// only re-added later (after the compiler auto-pruned the original blank
/// placeholder) — `addNavBarPage`'s dedup logic skips pages already present,
/// so the edit script's `app.bottomNav(...)` just appended Home at the end
/// instead of reordering.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildNavBarOrderFix,
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

void buildNavBarOrderFix(App app) {
  app.raw((project) {
    final homeKey = findPage(project, name: 'HomePage')!.node.key;

    // Codegen actually derives the bottom-nav tab order from `pageKeys`
    // (page declaration/creation order), not from `navBar.pageKeyRefOrder`.
    // HomePage was declared last (re-added after the original blank
    // placeholder got pruned), so it always rendered last regardless of
    // `pageKeyRefOrder`. Move its key to the front here too.
    final pageKeys = project.pageKeys;
    final pageIndex = pageKeys.indexOf(homeKey);
    pageKeys.removeAt(pageIndex);
    pageKeys.insert(0, homeKey);

    // `.navBar` (plain getter) doesn't attach an unset singular message to
    // the project — mutating it is a silent no-op. `.ensureNavBar()` is the
    // proto-generated `$_ensure` accessor that actually attaches it.
    final order = project.ensureNavBar().pageKeyRefOrder;

    // Clean up the stale orphaned ref left over from the original blank
    // HomePage placeholder (pruned from `pageKeys`/`widgetClasses`, but
    // never removed from this list).
    order.removeWhere((ref) => !project.widgetClasses.containsKey(ref.key));

    final navIndex = order.indexWhere((ref) => ref.key == homeKey);
    final item = order.removeAt(navIndex);
    order.insert(0, item);
  });
}
