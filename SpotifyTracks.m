let
    // 1. Configurações e Parâmetros
    Client_ID = "e09c6fcb30e540a8aed946e1d9e86b17",
    Client_Secret = "dabf9b13d3934b75bed00eb8a02fba1b",
    Search_Term = "V-Mode",
    User_ID = "8jtopaclkzi6fkcxvnzy3t27q", // INSIRA SEU ID DE USUÁRIO DO SPOTIFY AQUI

    // 2. Função para Obter o Token de Acesso (Anônimo)
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

    // 3. Buscar Playlists do Usuário (Listar todas as playlists do usuário para filtrar)
    // Nota: O endpoint de busca geral pode trazer playlists de terceiros. 
    // Para ser 100% preciso no seu perfil, listamos as suas playlists.
    Url = "https://api.spotify.com/v1/users/" & User_ID & "/playlists?limit=50",
    
    GetResponse = (targetUrl) => 
        let
            Res = Web.Contents(targetUrl, [Headers = [#"Authorization" = "Bearer " & AccessToken]]),
            Json = Json.Document(Res)
        in
            Json,

    // Paginação para buscar todas as playlists do usuário (caso tenha mais de 50)
    Pages = List.Generate(
        () => [Result = GetResponse(Url)],
        each [Result] <> null,
        each [Result = if [Result][next] <> null then GetResponse([Result][next]) else null],
        each [Result][items]
    ),
    
    AllPlaylists = List.Combine(Pages),
    TableFromList = Table.FromList(AllPlaylists, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    Expanded = Table.ExpandRecordColumn(TableFromList, "Column1", {"name", "id", "owner"}, {"Nome da Playlist", "ID Playlist", "owner"}),
    
    // 4. Aplicar Filtros (Palavra-chave e Dono)
    FilterByOwner = Table.SelectRows(Expanded, each ([owner][id] = User_ID)),
    FilterByKeyword = Table.SelectRows(FilterByOwner, each Text.Contains([Nome da Playlist], Search_Term, Comparer.OrdinalIgnoreCase)),
    
    // Selecionar colunas finais
    FinalTable = Table.SelectColumns(FilterByKeyword, {"Nome da Playlist", "ID Playlist"}),
    #"Função Personalizada Invocada" = Table.AddColumn(FinalTable, "Dados das Musicas", each GetPlaylistTracks([ID Playlist])),
    #"Dados das Musicas Expandido" = Table.ExpandTableColumn(#"Função Personalizada Invocada", "Dados das Musicas", {"Nome da Música", "Artistas", "Nome do Álbum", "Popularidade", "Duração (ms)", "Data Adição", "Gêneros", "URL Capa Álbum", "URL Foto Artista", "ID Música", "ID Artista Principal"}, {"Nome da Música", "Artistas", "Nome do Álbum", "Popularidade", "Duração (ms)", "Data Adição", "Gêneros", "URL Capa Álbum", "URL Foto Artista", "ID Música", "ID Artista Principal"}),
    #"Tipo Alterado" = Table.TransformColumnTypes(#"Dados das Musicas Expandido",{{"Popularidade", Int64.Type}, {"Duração (ms)", Int64.Type}, {"Data Adição", type datetime}})
in
    #"Tipo Alterado"