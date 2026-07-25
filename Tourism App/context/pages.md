## Pages (4)
- HomePage [`Scaffold_sk2lcarg`] [initial]
  - Navigates to: DetailPage
  - Components: PlaceCard
  - State: places (List<DataStruct<Place>>), isLoading (Boolean), likeMultiplier (Integer)
- DetailPage [`Scaffold_fa9xpm98`] → detail
  - Params: placeId (Integer)
  - State: place (DataStruct<Place>), isLoading (Boolean)
- SearchPage [`Scaffold_4a89t92k`] → search
  - Navigates to: DetailPage
  - Components: PlaceCard
  - State: searchQuery (String), results (List<DataStruct<Place>>), hasSearched (Boolean), isLoading (Boolean)
- FavoritesPage [`Scaffold_brkp53av`] → favorites

