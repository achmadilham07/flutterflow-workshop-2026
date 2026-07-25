library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:tourism_app/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildFixHomePage,
      apiKey: options.apiKey,
      baseUrl: options.baseUrl,
      projectName: options.projectName,
      projectId: options.projectId,
      findOrCreate: options.findOrCreate,
      allowNewProject: options.allowNewProject,
      dryRun: options.dryRun,
      commitMessage: options.commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

final class _CliOptions {
  const _CliOptions({
    this.apiKey,
    this.baseUrl,
    this.projectName,
    this.projectId,
    this.findOrCreate = false,
    this.allowNewProject = false,
    this.dryRun = false,
    this.commitMessage,
  });

  final String? apiKey;
  final String? baseUrl;
  final String? projectName;
  final String? projectId;
  final bool findOrCreate;
  final bool allowNewProject;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey;
  String? baseUrl;
  String? projectName;
  String? projectId;
  String? commitMessage;
  var findOrCreate = false;
  var allowNewProject = false;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
      case '--api-key':
        apiKey = _requireValue(args, ++i, '--api-key');
      case '--base-url':
        baseUrl = _requireValue(args, ++i, '--base-url');
      case '--project-name':
        projectName = _requireValue(args, ++i, '--project-name');
      case '--project-id':
        projectId = _requireValue(args, ++i, '--project-id');
      case '--commit-message':
        commitMessage = _requireValue(args, ++i, '--commit-message');
      case '--find-or-create':
        findOrCreate = true;
      case '--allow-new-project':
        allowNewProject = true;
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: $arg');
        _printUsage();
        exit(64);
    }
  }

  return _CliOptions(
    apiKey: apiKey,
    baseUrl: baseUrl,
    projectName: projectName,
    projectId: projectId,
    findOrCreate: findOrCreate,
    allowNewProject: allowNewProject,
    dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

String _requireValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    stderr.writeln('Missing value for $flag.');
    _printUsage();
    exit(64);
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('''
Run the starter FlutterFlow AI edit flow.

Usage:
  dart run dsl/edit.dart [options]

Options:
  --api-key <key>           FlutterFlow API key. Defaults to FF_API_KEY.
  --base-url <url>          Override the FlutterFlow API base URL.
  --project-name <name>     Create a new project with this name.
  --project-id <id>         Push into an existing project by ID.
  --find-or-create          Retry by reusing a same-name project before creating.
  --allow-new-project       Bypass the workspace binding guard and create a different project.
  --commit-message <text>   Commit message for the push.
  --dry-run                 Compile and validate without pushing.
  --help, -h                Show this help.
''');
}

void buildFixHomePage(App app) {
  // The project template's blank `HomePage` collided with our own
  // `app.page('HomePage', ...)` on the original create run, so that run
  // used `app.ensurePage(...)` instead — which only guarantees existence
  // and no-ops on body/state/onLoad for a page that's already there. The
  // untouched blank page was then auto-pruned by the compiler (it deletes
  // an unmodified placeholder once real pages exist), which also reset
  // the initial page to DetailPage and dropped Home from the bottom nav.
  // `HomePage` is a free name again now, so this adds it back for real
  // via a plain `app.page(...)` and re-wires the bottom nav to include it.
  final listPlaces = Endpoint.get(
        'ListPlaces',
        '/list',
        response: ff.Structs.placeListResponse,
      )
      ..attachToGroup(ff.ApiGroups.tourismApi);

  // Workaround: the generated typed handle (`ff.Components.placeCard`)
  // reports `onTapAction` as a `json` param type instead of `action` — a
  // codegen lossiness for action-typed component params. Calling
  // `ff.Components.placeCard(onTapAction: Navigate(...))` therefore fails
  // to compile ("Expected a DSL expression or scalar literal: Instance of
  // 'Navigate'"). Rebuild the same handle locally with the correct
  // `paramTypes` (same name/key, so it still resolves to the real remote
  // component) and place instances through it instead.
  final placeCardHandle = ProjectComponentHandle(
    name: ff.Components.placeCard.name,
    key: ff.Components.placeCard.key,
    params: ff.Components.placeCard.params,
    state: ff.Components.placeCard.state,
    widgets: ff.Components.placeCard.widgets,
    description: ff.Components.placeCard.description,
    paramTypes: const {
      'onTapAction': action,
      'placeDescription': string,
      'placeImage': string,
      'placeLike': int_,
      'placeName': string,
    },
  );
  DslWidget placeCard({
    required Object placeName,
    required Object placeDescription,
    required Object placeLike,
    required Object placeImage,
    required Object onTapAction,
  }) => ComponentInstance(
    component: placeCardHandle,
    arguments: {
      'placeName': placeName,
      'placeDescription': placeDescription,
      'placeLike': placeLike,
      'placeImage': placeImage,
      'onTapAction': onTapAction,
    },
  );

  final homePage = app.page(
    'HomePage',
    route: '/',
    isInitial: true,
    description: 'Lists tourism destinations from GET /list.',
    state: {'places': listOf(ff.Structs.place), 'isLoading': bool_.withDefault(true)},
    onLoad: [
      ApiCall(
        listPlaces,
        outputAs: 'listPlacesResult',
        onSuccess:
            (res) => [
              SetState('places', res['places']),
              SetState('isLoading', false),
            ],
        onFailure: [
          SetState('isLoading', false),
          Snackbar('Failed to load places'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Tourism App'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          crossAxis: CrossAxis.stretch,
          children: [
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Expanded(
              ListView(
                source: State('places'),
                visible: Not(State('isLoading')),
                itemBuilder:
                    (item) => placeCard(
                      placeName: item['name'],
                      placeDescription: item['description'],
                      placeLike: item['like'],
                      placeImage: item['image'],
                      onTapAction: Navigate(
                        ff.Pages.detailPage,
                        params: {'placeId': item['id']},
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  app.bottomNav(
    items: [
      BottomNavItem(homePage, icon: 'home'),
      BottomNavItem(ff.Pages.searchPage, icon: 'search'),
      BottomNavItem(ff.Pages.favoritesPage, icon: 'favorite'),
    ],
    backgroundColor: Colors.secondaryBackground,
    selectedColor: Colors.primary,
    unselectedColor: Colors.secondaryText,
  );
}
