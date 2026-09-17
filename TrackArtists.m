let
    /* 
       INSTRUÇÃO: Substitua #"NOME_DA_SUA_CONSULTA" pelo nome da consulta 
       que você criou no Passo 3 do Guia (ex: #"Busca Playlists").
    */
    Fonte = #"SpotifyTracks",

    // 1. Selecionar as colunas base solicitadas, incluindo "Gêneros"
    ColunasSelecionadas = Table.SelectColumns(Fonte, {"ID Música", "Nome da Música", "Artistas", "Gêneros"}),

    // 2. Determinar dinamicamente o número máximo de colunas de artistas necessárias
    ContagemArtistas = List.Max(List.Transform(ColunasSelecionadas[Artistas], each if _ is null then 0 else List.Count(Text.Split(_, "; ")))),
    NomesColunasArtistas = List.Transform({1..ContagemArtistas}, each "Artista " & Text.From(_)),

    // 3. Dividir a coluna "Artistas" em múltiplas colunas
    ArtistasDivididos = Table.SplitColumn(
        ColunasSelecionadas,
        "Artistas",
        Splitter.SplitTextByDelimiter("; ", QuoteStyle.Csv),
        NomesColunasArtistas
    ),

    // 4. Determinar dinamicamente o número máximo de colunas de gêneros necessárias
    ContagemGeneros = List.Max(List.Transform(ArtistasDivididos[Gêneros], each if _ is null or _ = "" then 0 else List.Count(Text.Split(_, ", ")))),
    NomesColunasGeneros = List.Transform({1..ContagemGeneros}, each "Gênero " & Text.From(_)),

    // 5. Dividir a coluna "Gêneros" em múltiplas colunas
    Resultado = Table.SplitColumn(
        ArtistasDivididos,
        "Gêneros",
        Splitter.SplitTextByDelimiter(", ", QuoteStyle.Csv),
        NomesColunasGeneros
    )
in
    Resultado