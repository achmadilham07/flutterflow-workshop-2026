library;

/// Phase B of the main -> baseline-starter reset (see reset_main_to_starter_a.dart
/// for phase A and the reason for the split). Runs after a context refresh
/// so `res['places']` resolves against the renamed struct field.
///
/// 1. DetailPage: remove `isFavorited` / `favoriteDocRef` state, replace the
///    ToggleIcon row with a plain Text, restore the original single-
///    `GetPlaceDetail` onLoad (drops the Firestore favorite-check).
/// 2. FavoritesPage: replace the Firestore-bound ListView with the original
///    empty-state placeholder.
///
/// This removes every remaining reference to the `favorites` collection;
/// phase C then removes the collection itself.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildResetB,
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

void buildResetB(App app) {
  // 1. Revert DetailPage.
  app.raw((project) {
    final page = findPage(project, name: 'DetailPage')!;
    page.classModel.stateFields.removeWhere(
      (f) =>
          f.parameter.identifier.name == 'isFavorited' ||
          f.parameter.identifier.name == 'isFavorite' ||
          f.parameter.identifier.name == 'favoriteDocRef',
    );
  });
  app.editPage(ff.Pages.detailPage, (page) {
    page.ensureReplaced(
      page.findByKey('Row_tj34zi0o'),
      Text(
        State('place')['name'],
        style: Styles.headlineSmall,
        name: 'PlaceName',
      ),
    );
  });
  app.editPageOnLoad(ff.Pages.detailPage, [
    ApiCall(
      Endpoint.get(
            'GetPlaceDetail',
            '/detail/[id]',
            variables: {'id': int_},
            response: ff.Structs.placeDetailResponse,
          )
          ..attachToGroup(ff.ApiGroups.tourismApi),
      outputAs: 'getPlaceDetailResult',
      params: {'id': PageParam('placeId')},
      onSuccess:
          (res) => [
            SetState('place', res['places']),
            SetState('isLoading', false),
          ],
      onFailure: [
        SetState('isLoading', false),
        Snackbar('Failed to load place detail'),
      ],
    ),
  ]);

  // 2. Revert FavoritesPage.
  app.raw((project) {
    final page = findPage(project, name: 'FavoritesPage')!;
    page.classModel.stateFields.removeWhere(
      (f) => f.parameter.identifier.name == 'favoriteIdResult' || f.parameter.identifier.name == 'isListExist',
    );
  });
  app.editPage(ff.Pages.favoritesPage, (page) {
    page.ensureReplaced(
      page.findByKey('ListView_cvx97xnc'),
      Container(
        name: 'FavoritesEmptyState',
        color: Colors.primaryBackground,
        alignment: Alignment.center,
        padding: 24,
        child: Column(
          mainAxis: MainAxis.center,
          spacing: 12,
          children: [
            Icon('favorite_border', size: 48, color: Colors.secondaryText),
            Text('No favorites yet', style: Styles.titleMedium),
            Text(
              "Firestore isn't connected yet - favorites will appear here once it's wired up.",
              style: Styles.bodySmall,
              color: Colors.secondaryText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  });
}
