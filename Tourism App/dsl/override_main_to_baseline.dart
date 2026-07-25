library;

/// Overrides `main` so it matches `baseline-starter` again, discarding all
/// manual rehearsal work done directly on main since the branches diverged:
///
/// 1. Reintroduces the Segmen 1 bug (`PlaceDetailResponse.place` -> `.places`).
/// 2. Adds `inflateLikeCounts` custom action + wires it into HomePage's
///    onLoad (matches baseline-starter's like-count-inflation experiment).
/// 3. Removes the Firestore `favorites` collection.
/// 4. Reverts `DetailPage`: drops the ToggleIcon/Favorite wiring (collapses
///    the wrapping Row back to a plain Text), removes the `isFavorited` /
///    `favoriteDocRef` state fields, and restores the original single
///    ApiCall onLoad (drops the added Backend Query favorite-check).
/// 5. Reverts `FavoritesPage`: replaces the Firestore-bound ListView body
///    with the original empty-state placeholder, removes the
///    `favoriteIdResult` / `isListExist` state fields.
///
/// Explicit, confirmed destructive action — main's hand-built Firestore
/// integration is intentionally discarded here.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildOverride,
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

void buildOverride(App app) {
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

  // 2. Add inflateLikeCounts + wire into HomePage onLoad.
  final listPlaces = Endpoint.get(
        'ListPlaces',
        '/list',
        response: ff.Structs.placeListResponse,
      )
      ..attachToGroup(ff.ApiGroups.tourismApi);

  final inflateLikeCounts = app.customAction(
    'inflateLikeCounts',
    args: {'places': listOf(ff.Structs.place), 'multiplier': int_},
    returns: listOf(ff.Structs.place),
    description:
        'Demo: multiplies each place\'s like count so formatLikeCount\'s '
        '>=1000 branch is reachable with real API data.',
    code: r'''
Future<List<PlaceStruct>> inflateLikeCounts(
  List<PlaceStruct> places,
  int multiplier,
) async {
  return places
      .map(
        (p) => createPlaceStruct(
          id: p.id,
          name: p.name,
          description: p.description,
          address: p.address,
          longitude: p.longitude,
          latitude: p.latitude,
          like: p.like * multiplier,
          image: p.image,
        ),
      )
      .toList();
}
''',
  );

  app.editPageState(ff.Pages.homePage, (state) {
    state.ensureField('likeMultiplier', int_.withDefault(50));
  });

  app.editPageOnLoad(ff.Pages.homePage, [
    ApiCall(
      listPlaces,
      outputAs: 'listPlacesResult',
      onSuccess:
          (res) => [
            CallCustomAction(
              inflateLikeCounts,
              args: {
                'places': res['places'],
                'multiplier': State('likeMultiplier'),
              },
              outputAs: 'inflatedPlaces',
            ),
            SetState('places', ActionOutput('inflatedPlaces')),
            SetState('isLoading', false),
          ],
      onFailure: [
        SetState('isLoading', false),
        Snackbar('Failed to load places'),
      ],
    ),
  ]);

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
      page.findByKey('Row_h7pn575q'),
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
      page.findByKey('ListView_i97fuuy8'),
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
