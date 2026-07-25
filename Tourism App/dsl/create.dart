library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildTourismApp,
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
Build and push the Tourism App placeholder to FlutterFlow.

Usage:
  dart run dsl/create.dart [options]

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

void buildTourismApp(App app) {
  // ====================== THEME ======================

  app.themeColor('primary', 0xFF2F6F4E);
  app.themeColor('secondary', 0xFF0F9D8A);
  app.themeColor('primaryBackground', 0xFFF8FAF9);
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('primaryText', 0xFF14181B);
  app.themeColor('secondaryText', 0xFF57636C);
  app.primaryFont('Inter');

  // ====================== DATA MODEL ======================

  final place = app.struct('Place', {
    'id': int_,
    'name': string,
    'description': string,
    'address': string,
    'longitude': double_,
    'latitude': double_,
    'like': int_,
    'image': string,
  });

  final placeListResponse = app.struct('PlaceListResponse', {
    'error': bool_,
    'message': string,
    'count': int_,
    'places': listOf(place),
  });

  final placeSearchResponse = app.struct('PlaceSearchResponse', {
    'error': bool_,
    'message': string,
    'places': listOf(place),
  });

  // Segment-1 debugging demo: this schema wrongly assumes /detail/{id}
  // returns the same `places` array shape as /list and /search. The real
  // endpoint returns a singular `place` object, so `places` resolves to
  // null at runtime and DetailPage opens broken on purpose — fixed live
  // with AI help during Segment 1.
  final placeDetailResponse = app.struct('PlaceDetailResponse', {
    'error': bool_,
    'message': string,
    'places': place,
  });

  // ====================== API ======================

  final listPlaces = Endpoint.get(
    'ListPlaces',
    '/list',
    response: placeListResponse,
  );
  final getPlaceDetail = Endpoint.get(
    'GetPlaceDetail',
    '/detail/[id]',
    variables: {'id': int_},
    response: placeDetailResponse,
  );
  final searchPlaces = Endpoint.get(
    'SearchPlaces',
    '/search?q=[q]',
    variables: {'q': string},
    response: placeSearchResponse,
  );

  app.apiGroup(
    'TourismApi',
    baseUrl: 'https://tourism-api.dicoding.dev',
    endpoints: [listPlaces, getPlaceDetail, searchPlaces],
  );

  // ====================== COMPONENTS ======================

  final dynamic placeCard = app.component(
    'PlaceCard',
    description: 'Tourism place summary card used on Home and Search.',
    params: {
      'placeName': string.withDefault(''),
      'placeDescription': string.withDefault(''),
      'placeLike': int_.withDefault(0),
      'placeImage': string.withDefault(''),
      'onTapAction': action,
    },
    body: Container(
      onTap: ParamAction('onTapAction'),
      color: Colors.secondaryBackground,
      borderRadius: 12,
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxis: CrossAxis.start,
        children: [
          Image(
            Param('placeImage'),
            width: 96,
            height: 96,
            fit: ImageFit.cover,
            borderRadius: 12,
          ),
          Expanded(
            Container(
              padding: 12,
              child: Column(
                crossAxis: CrossAxis.start,
                spacing: 4,
                children: [
                  Text(
                    Param('placeName'),
                    style: Styles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    Param('placeDescription'),
                    style: Styles.bodySmall,
                    color: Colors.secondaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    spacing: 4,
                    children: [
                      Icon('favorite', size: 14, color: Colors.error),
                      Text(
                        Param('placeLike'),
                        style: Styles.labelSmall,
                        color: Colors.secondaryText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ====================== PAGES ======================

  final homePage = app.ensurePage(
    'HomePage',
    route: '/',
    isInitial: true,
    description: 'Lists tourism destinations from GET /list.',
    state: {'places': listOf(place), 'isLoading': bool_.withDefault(true)},
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
                        'DetailPage',
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

  app.page(
    'DetailPage',
    route: '/detail',
    description: 'Shows one tourism place from GET /detail/{id}.',
    params: {'placeId': int_.withDefault(0)},
    state: {'place': place, 'isLoading': bool_.withDefault(true)},
    onLoad: [
      ApiCall(
        getPlaceDetail,
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
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Place Detail'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 20,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Column(
              crossAxis: CrossAxis.start,
              spacing: 12,
              visible: Not(State('isLoading')),
              children: [
                Image(
                  State('place')['image'],
                  width: double.infinity,
                  height: 220,
                  fit: ImageFit.cover,
                  borderRadius: 16,
                ),
                Text(State('place')['name'], style: Styles.headlineSmall),
                Text(
                  State('place')['address'],
                  style: Styles.bodyMedium,
                  color: Colors.secondaryText,
                ),
                Text(
                  State('place')['description'],
                  style: Styles.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  final searchPage = app.page(
    'SearchPage',
    route: '/search',
    description: 'Searches tourism places via GET /search?q=.',
    state: {
      'searchQuery': string.withDefault(''),
      'results': listOf(place),
      'hasSearched': bool_.withDefault(false),
      'isLoading': bool_.withDefault(false),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Search'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          crossAxis: CrossAxis.stretch,
          spacing: 12,
          children: [
            TextField(
              hint: 'Search destinations...',
              prefixIcon: 'search',
              onChanged: SetState('searchQuery', TextValue()),
              onSubmitted: [
                SetState('isLoading', true),
                ApiCall(
                  searchPlaces,
                  outputAs: 'searchPlacesResult',
                  params: {'q': State('searchQuery')},
                  onSuccess:
                      (res) => [
                        SetState('results', res['places']),
                        SetState('hasSearched', true),
                        SetState('isLoading', false),
                      ],
                  onFailure: [
                    SetState('isLoading', false),
                    Snackbar('Search failed'),
                  ],
                ),
              ],
            ),
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Expanded(
              ListView(
                source: State('results'),
                visible: State('hasSearched'),
                itemBuilder:
                    (item) => placeCard(
                      placeName: item['name'],
                      placeDescription: item['description'],
                      placeLike: item['like'],
                      placeImage: item['image'],
                      onTapAction: Navigate(
                        'DetailPage',
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

  final favoritesPage = app.page(
    'FavoritesPage',
    route: '/favorites',
    description:
        'Placeholder for Firestore-backed favorites, wired in Segment 3.',
    body: Scaffold(
      appBar: AppBar(title: 'Favorites'),
      body: Container(
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
    ),
  );

  // ====================== NAVIGATION ======================

  app.bottomNav(
    items: [
      BottomNavItem(homePage, icon: 'home'),
      BottomNavItem(searchPage, icon: 'search'),
      BottomNavItem(favoritesPage, icon: 'favorite'),
    ],
    backgroundColor: Colors.secondaryBackground,
    selectedColor: Colors.primary,
    unselectedColor: Colors.secondaryText,
  );
}
