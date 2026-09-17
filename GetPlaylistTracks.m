(Playlist_ID as text) =>
let
    // 1. Configurações e Parâmetros
    Client_ID = "e09c6fcb30e540a8aed946e1d9e86b17",
    Client_Secret = "dabf9b13d3934b75bed00eb8a02fba1b",

    // 2. Função para Obter Token
    GetAccessToken = () =>
        let
            AuthBinary = Text.ToBinary(Client_ID & ":" & Client_Secret),
            EncodedAuth = "Basic " & Binary.ToText(AuthBinary, BinaryEncoding.Base64),
            TokenResponse = Web.Contents(
                "https://accounts.spotify.com/api/token",
                [
                    Headers = [
                        #"Authorization" = EncodedAuth,
                        #"Content-Type" = "application/x-www-form-urlencoded"
                    ],
                    Content = Text.ToBinary("grant_type=client_credentials")
                ]
            ),
            TokenJson = Json.Document(TokenResponse),
            AccessToken = TokenJson[access_token]
        in
            AccessToken,

    AccessToken = GetAccessToken(),

    // 3. Função de Busca de Página
    GetTracksPage = (url as text) =>
        let
            Response = Web.Contents(url, [Headers = [#"Authorization" = "Bearer " & AccessToken]]),
            Json = Json.Document(Response)
        in
            Json,

    // 4. Paginação de Músicas
    BaseUrl = "https://api.spotify.com/v1/playlists/" & Playlist_ID & "/tracks?limit=100",
    Pages = List.Generate(
        () => [Result = try GetTracksPage(BaseUrl) otherwise null],
        each [Result] <> null,
        each [Result = if [Result][next] <> null then try GetTracksPage([Result][next]) otherwise null else null],
        each [Result][items]
    ),
    CombinedItems = List.Combine(Pages),
    TableFromList = Table.FromList(CombinedItems, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    
    // 5. Expansão de Dados e Tratamento
    Expanded = Table.ExpandRecordColumn(TableFromList, "Column1", {"track", "added_at"}, {"track", "Data Adição"}),
    FilterNull = Table.SelectRows(Expanded, each [track] <> null),
    ExpandedTrack = Table.ExpandRecordColumn(FilterNull, "track", 
        {"name", "artists", "album", "popularity", "id", "duration_ms"}, 
    {"Nome da Música", "artists", "album", "Popularidade", "ID Música", "Duração (ms)"}
    ),

    // Extrair dados do álbum
    ExtractAlbumData = Table.ExpandRecordColumn(ExpandedTrack, "album", {"name", "images"}, {"Nome do Álbum", "album_images"}),
    ExtractAlbumCover = Table.TransformColumns(ExtractAlbumData, {{"album_images", each if _ <> null and List.Count(_) > 0 then _{0}[url] else null}}),
    RenameAlbumCover = Table.RenameColumns(ExtractAlbumCover, {{"album_images", "URL Capa Álbum"}}),

    // Concatenar nomes dos artistas e obter o ID do primeiro artista
    AddArtistInfo = Table.AddColumn(RenameAlbumCover, "ArtistInfo", each 
        let
            ArtistList = [artists],
            AllNames = if ArtistList <> null and List.Count(ArtistList) > 0 
                       then Text.Combine(List.Transform(ArtistList, each _[name]), "; ") 
                       else "Desconhecido",
            FirstID = if ArtistList <> null and List.Count(ArtistList) > 0 
                      then ArtistList{0}[id] 
                      else null
        in
            [Nomes = AllNames, ID_Principal = FirstID]
    ),
    ExpandArtistInfo = Table.ExpandRecordColumn(AddArtistInfo, "ArtistInfo", {"Nomes", "ID_Principal"}, {"Artistas", "ID Artista Principal"}),

    // Função para Detalhes (Gêneros e Foto)
    GetArtistDetails = (artist_id as any) =>
        let
            Details = if artist_id = null then [Genres = "", ArtistImage = null] else
                let
                    ArtistResponse = Web.Contents("https://api.spotify.com/v1/artists/" & artist_id, [Headers = [#"Authorization" = "Bearer " & AccessToken], ManualStatusHandling = {404, 400}]),
                    ArtistJson = Json.Document(ArtistResponse),
                    Genres = if Record.HasFields(ArtistJson, "genres") then Text.Combine(ArtistJson[genres], ", ") else "",
                    ImageUrl = if Record.HasFields(ArtistJson, "images") and List.Count(ArtistJson[images]) > 0 then ArtistJson[images]{0}[url] else null
                in
                    [Genres = Genres, ArtistImage = ImageUrl]
        in
            Details,

    AddArtistDetails = Table.AddColumn(ExpandArtistInfo, "ArtistDetails", each GetArtistDetails([ID Artista Principal])),
    ExpandArtistDetails = Table.ExpandRecordColumn(AddArtistDetails, "ArtistDetails", {"Genres", "ArtistImage"}, {"Gêneros", "URL Foto Artista"}),

    // Limpeza Final
    Final = Table.SelectColumns(ExpandArtistDetails, {"Nome da Música", "Artistas", "Nome do Álbum", "Popularidade", "Duração (ms)","Data Adição", "Gêneros", "URL Capa Álbum", "URL Foto Artista", "ID Música", "ID Artista Principal"})
in
    Final