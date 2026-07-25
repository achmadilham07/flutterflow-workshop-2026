library;

/// EXPERIMENTAL — baseline-starter branch only. Do NOT merge to main.
///
/// Real Tourism API like counts are all well under 1000, so `formatLikeCount`'s
/// `>= 1000` branch (the "1.2K suka" formatting) never actually fires against
/// live data during the demo. This adds a demo-only Custom Action that scales
/// up each place's `like` count after the `/list` fetch, so the K-formatting
/// path is reachable live without touching `formatLikeCount` itself or the
/// real API data.
import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildInflateLikesExperiment,
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

void buildInflateLikesExperiment(App app) {
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
        'DEMO ONLY (baseline-starter): scales up each place\'s like count '
        'so formatLikeCount\'s >=1000 "K suka" branch is reachable with real '
        'Tourism API data, which is always under 1000 likes.',
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
}
