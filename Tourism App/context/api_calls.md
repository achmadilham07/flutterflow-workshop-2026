## API Calls
### Group: TourismApi (https://tourism-api.dicoding.dev)
- ListPlaces [GET] /list
  - Response: DataStruct<PlaceListResponse>
- GetPlaceDetail [GET] /detail/[id]
  - Variables: id (Integer)
  - Response: DataStruct<PlaceDetailResponse>
- SearchPlaces [GET] /search?q=[q]
  - Variables: q (String)
  - Response: DataStruct<PlaceSearchResponse>

