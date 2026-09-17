# Spotify Playlist Tool

Integração entre a API do Spotify e o **Microsoft Power BI** usando consultas **Power Query (M)**. O projeto localiza playlists de um usuário, percorre suas faixas com paginação, enriquece os registros com dados de álbuns e artistas e disponibiliza o resultado para análises no relatório Power BI.

> **Status da documentação:** baseada na estrutura do repositório, nas consultas M versionadas e no arquivo PBIX incluído. Fórmulas DAX, relacionamentos e configurações internas do modelo semântico devem ser validados no Power BI Desktop.

## Objetivos

O projeto foi desenvolvido para:

- localizar playlists pertencentes a um usuário do Spotify por palavra-chave;
- carregar todas as faixas dessas playlists, respeitando a paginação da API;
- extrair título, artistas, álbum, popularidade, duração e data de adição;
- obter gêneros e imagem do artista principal;
- disponibilizar os dados para indicadores, tabelas e filtros no Power BI;
- separar a transformação principal da normalização de artistas e gêneros.

## Estrutura do repositório

| Arquivo | Responsabilidade |
|---|---|
| `Spotify Playlist API.pbix` | Relatório Power BI e modelo semântico do projeto. |
| `SpotifyTracks.m` | Consulta principal: autenticação, busca e filtragem de playlists, chamada da função de faixas e tipagem final. |
| `GetPlaylistTracks.m` | Função parametrizada que recebe um ID de playlist, pagina as faixas e consulta dados complementares do artista. |
| `TrackArtists.m` | Consulta auxiliar que separa artistas e gêneros concatenados em colunas individuais. |
| `README.md` | Documentação de configuração, arquitetura, fluxo e manutenção. |

## Arquitetura e fluxo de dados

```mermaid
flowchart TD
    A[Parâmetros do Spotify] --> B[SpotifyTracks.m]
    B --> C[POST /api/token]
    C --> D[Token de acesso]
    D --> E[GET /users/{id}/playlists]
    E --> F{Playlist corresponde ao usuário e termo?}
    F -->|Sim| G[GetPlaylistTracks.m]
    F -->|Não| H[Descartar]
    G --> I[GET /playlists/{id}/tracks]
    I --> J[Paginação de faixas]
    J --> K[Dados do álbum e da faixa]
    K --> L[GET /artists/{id}]
    L --> M[Gêneros e imagem do artista]
    M --> N[Tabela SpotifyTracks]
    N --> O[TrackArtists.m]
    N --> P[Modelo e visuais do Power BI]
    O --> P
```

### Sequência de execução

1. `SpotifyTracks.m` define o ID do cliente, o segredo, o ID do usuário e o termo de busca.
2. A consulta solicita um token usando o fluxo `client_credentials`.
3. As playlists do usuário são carregadas em páginas de até 50 itens.
4. O resultado é filtrado pelo proprietário e por `Search_Term`, sem diferenciação entre maiúsculas e minúsculas.
5. Para cada playlist encontrada, `GetPlaylistTracks.m` é chamado com o ID correspondente.
6. As faixas são carregadas em páginas de até 100 itens.
7. Registros sem faixa válida são removidos e os campos do álbum, faixa e artista são expandidos.
8. O artista principal é consultado para obter gêneros e imagem.
9. `TrackArtists.m` divide as listas concatenadas de artistas e gêneros em colunas analíticas.

## Configuração

### Pré-requisitos

- Microsoft Power BI Desktop;
- acesso à internet para chamar `accounts.spotify.com` e `api.spotify.com`;
- uma aplicação criada no [Spotify for Developers](https://developer.spotify.com/dashboard);
- credenciais de cliente da aplicação;
- ID do usuário do Spotify;
- permissão para atualizar consultas Power Query e abrir o arquivo PBIX.

### Parâmetros necessários

Os valores usados atualmente nas consultas são:

| Parâmetro | Uso |
|---|---|
| `Client_ID` | Identifica a aplicação do Spotify. |
| `Client_Secret` | Autentica a aplicação no endpoint de token. |
| `User_ID` | Identifica o usuário cujas playlists serão consultadas. |
| `Search_Term` | Termo usado para filtrar o nome das playlists. |

Para uma instalação segura, esses valores devem ser transformados em parâmetros do Power Query ou em outra forma de configuração protegida. **Não coloque segredos diretamente no código, no README ou em commits.** Se um segredo já tiver sido versionado, ele deve ser revogado e substituído no painel do Spotify.

### Configuração no Power BI Desktop

1. Abra `Spotify Playlist API.pbix`.
2. No **Editor do Power Query**, localize `SpotifyTracks` e atualize os parâmetros de configuração.
3. Confirme que a função `GetPlaylistTracks` está disponível com esse nome, pois `SpotifyTracks` a invoca para cada playlist filtrada.
4. Confirme que `TrackArtists` referencia a consulta `SpotifyTracks`.
5. Atualize a prévia e valide se as consultas conseguem acessar os endpoints do Spotify.
6. Revise as credenciais da fonte de dados nas configurações do Power BI.
7. Atualize o modelo e verifique os visuais antes de publicar ou compartilhar o relatório.

## Consultas Power Query

### `SpotifyTracks.m`

É a consulta orquestradora. Ela obtém o token, lista as playlists do usuário, percorre a paginação por meio do campo `next`, filtra as playlists e expande os dados retornados por `GetPlaylistTracks`.

O resultado final contém, entre outros, os seguintes campos:

- `Nome da Playlist`;
- `Nome da Música`;
- `Artistas`;
- `Nome do Álbum`;
- `Popularidade`;
- `Duração (ms)`;
- `Data Adição`;
- `Gêneros`;
- `URL Capa Álbum`;
- `URL Foto Artista`;
- `ID Música`;
- `ID Artista Principal`.

### `GetPlaylistTracks.m`

É uma função com assinatura `(Playlist_ID as text)`. Ela busca as faixas da playlist usando páginas de até 100 itens, remove registros cujo objeto `track` é nulo, extrai informações do álbum e concatena os nomes dos artistas com `; `.

Para o primeiro artista de cada faixa, a função consulta o endpoint de detalhes do artista. Dessa resposta são extraídos os gêneros, separados por `, `, e a primeira imagem disponível.

### `TrackArtists.m`

Seleciona ID, nome, artistas e gêneros a partir de `SpotifyTracks`. Como artistas e gêneros são armazenados em texto delimitado, a consulta calcula dinamicamente a quantidade máxima encontrada e cria colunas como `Artista 1`, `Artista 2`, `Gênero 1` e `Gênero 2`.

Essa transformação é útil para análises tabulares, mas amplia o número de colunas conforme os dados mudam. Para um modelo dimensional mais robusto, considere normalizar artistas e gêneros em tabelas de relacionamento, em vez de criar colunas variáveis.

## API e paginação

| Recurso | Endpoint usado | Tamanho de página |
|---|---|---:|
| Token de aplicação | `POST https://accounts.spotify.com/api/token` | — |
| Playlists do usuário | `GET https://api.spotify.com/v1/users/{user_id}/playlists` | 50 |
| Faixas da playlist | `GET https://api.spotify.com/v1/playlists/{playlist_id}/tracks` | 100 |
| Detalhes do artista | `GET https://api.spotify.com/v1/artists/{artist_id}` | 1 por chamada |

A paginação usa o campo `next` retornado pelo Spotify. Quando `next` é nulo, a consulta encerra a geração de páginas.

## Relatório Power BI

O arquivo `Spotify Playlist API.pbix` fornece a camada de apresentação. A definição exata dos visuais e das medidas deve ser conferida no Power BI Desktop, mas o conjunto de dados produzido pelas consultas suporta análises de:

- volume de faixas por playlist, artista, álbum e gênero;
- popularidade e duração das faixas;
- tempo total de escuta estimado a partir da duração;
- última faixa adicionada;
- capas de álbuns e imagens de artistas;
- filtros por playlist, faixa, artista e data de adição.

O relatório pode conter medidas e visuais que dependem de nomes específicos. Ao renomear colunas, preserve a compatibilidade com as consultas, medidas e visuais existentes.

## Limitações e comportamento atual

- O fluxo `client_credentials` representa a aplicação, não uma autorização completa do usuário. Endpoints que exigem escopos de usuário ou operações de escrita não estão cobertos por estas consultas.
- O código não implementa uma política explícita de retry com backoff para limites de requisição, falhas transitórias ou respostas `429`.
- A consulta de detalhes de artista faz uma chamada individual por faixa, usando apenas o artista principal; isso pode aumentar bastante o tempo de atualização e produzir chamadas repetidas para o mesmo artista.
- O tratamento de erros em `GetPlaylistTracks` converte falhas de página em `null`, o que pode ocultar a causa de uma atualização incompleta.
- O filtro depende de correspondência no nome da playlist e pode retornar zero linhas se o termo não for encontrado.
- A divisão dinâmica de artistas e gêneros em colunas pode dificultar a modelagem quando a quantidade de valores varia entre atualizações.

## Recomendações de manutenção

1. Remover credenciais do código e rotacionar imediatamente qualquer segredo que tenha sido exposto ou versionado.
2. Extrair parâmetros do Power Query para uma configuração segura e documentar apenas nomes, não valores secretos.
3. Criar uma camada de cache ou uma consulta distinta de artistas para evitar chamadas repetidas.
4. Implementar tratamento explícito de `401`, `404`, `429` e erros `5xx`, incluindo registro ou indicador de atualização parcial.
5. Considerar tabelas normalizadas de faixas, artistas, gêneros e playlists para reduzir a dependência de colunas dinâmicas.
6. Validar no Power BI os tipos de dados, relacionamentos, medidas, credenciais e frequência de atualização.
7. Adicionar uma tabela calendário caso o relatório evolua para análises por mês, semana ou ano.

## Checklist de validação

- [ ] As credenciais estão armazenadas fora do código versionado.
- [ ] O ID do usuário e o termo de busca são válidos.
- [ ] A função `GetPlaylistTracks` está nomeada exatamente como esperado.
- [ ] A atualização percorre mais de uma página quando necessário.
- [ ] Playlists de outro proprietário não aparecem no resultado.
- [ ] Faixas removidas ou indisponíveis não interrompem a atualização.
- [ ] Os tipos de `Popularidade`, `Duração (ms)` e `Data Adição` estão corretos.
- [ ] Medidas e visuais do PBIX continuam renderizando.
- [ ] Os limites de requisição do Spotify são respeitados.

## Licença e responsabilidade

Este repositório não informa uma licença de software. Antes de redistribuir o código, o relatório ou dados derivados, defina uma licença e confirme as condições de uso da API e dos dados do Spotify.

O uso da marca, das imagens e dos dados do Spotify deve respeitar os [termos da plataforma](https://developer.spotify.com/terms) e as políticas aplicáveis.
