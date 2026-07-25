library;

/// Resets `main` back to the pristine `baseline-starter` state, discarding
/// all rehearsal work redone on main after the previous override
/// (`override_main_to_baseline.dart`) — that override's DetailPage/
/// FavoritesPage revert steps silently no-op'd because the anchor node keys
/// (`Row_h7pn575q`, `ListView_i97fuuy8`) had gone stale once the user
/// rebuilt the Favorite/Firestore UI by hand again in the FlutterFlow
/// editor, so main drifted right back to a "worked on" state.
///
/// Verified against `baseline-starter` (project TM44WPUaNGKK7H39PYsi) live
/// before writing this:
/// 1. `PlaceDetailResponse.place` -> `.places` bug: already present on main.
/// 2. PlaceCard's description/like Text widgets: rebind to plain params,
///    remove `truncateDescription` / `formatLikeCount` (`formatDistance`
///    was already gone).
/// 3. Remove the `favorites` Firestore collection.
/// 4. DetailPage: remove `isFavorited` / `favoriteDocRef` state, replace the
///    current `Row_hs0tifpt` (PlaceName + ToggleIcon) with a plain Text,
///    restore the original single-`GetPlaceDetail` onLoad.
/// 5. FavoritesPage: replace the current `ListView_49zd2a6a` (Firestore-
///    bound PlaceCard list) with the original empty-state placeholder.
/// 6. Re-break HomePage's PlaceCard navigation: clear the `onTapAction`
///    parameter pass on the HomePage ComponentInstance so tapping a card
///    does nothing again, matching baseline's un-fixed behavior.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildReset,
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

void buildReset(App app) {
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

  // 3. Remove the Firestore `favorites` collection.
  app.removeCollection('favorites');

  // 4. Revert DetailPage.
  app.raw((project) {
    final page = findPage(project, name: 'DetailPage')!;
    page.classModel.stateFields.removeWhere(
      (f) => f.parameter.identifier.name == 'isFavorited' || f.parameter.identifier.name == 'favoriteDocRef',
    );
  });
  app.editPage(ff.Pages.detailPage, (page) {
    page.ensureReplaced(
      page.findByKey('Row_hs0tifpt'),
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

  // 5. Revert FavoritesPage.
  app.raw((project) {
    final page = findPage(project, name: 'FavoritesPage')!;
    page.classModel.stateFields.removeWhere(
      (f) => f.parameter.identifier.name == 'favoriteIdResult' || f.parameter.identifier.name == 'isListExist',
    );
  });
  app.editPage(ff.Pages.favoritesPage, (page) {
    page.ensureReplaced(
      page.findByKey('ListView_49zd2a6a'),
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

  // 6. Re-break HomePage's PlaceCard navigation (clear the onTapAction
  //    argument on the ComponentInstance node so it compiles to a no-op
  //    again, matching baseline-starter's un-fixed behavior).
  app.raw((project) {
    final page = findPage(project, name: 'HomePage')!;
    final instanceNode = findByKey(page.node, 'Container_sx4d1mel');
    if (instanceNode == null) {
      throw StateError('HomePage PlaceCard instance node not found.');
    }
    final pass = instanceNode.parameterValues.parameterPasses['1tnq0roe'];
    if (pass != null) {
      pass.clearAction();
    }
  });
}
