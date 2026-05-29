# SICRO Operacional v1.0 Alpha

Versao alpha Android: `1.0.0-alpha+1`.

## Objetivo

O SICRO Operacional v0.1 e o aplicativo Android de apoio ao trabalho pericial em campo.
Ele nao substitui o SICRO desktop. Sua funcao e coletar, organizar e preservar
informacoes essenciais da ocorrencia para posterior importacao no SICRO desktop.

O ciclo principal do produto e:

```text
local da pericia -> coleta organizada -> arquivo .sicroapp
-> importacao no SICRO desktop -> estudo do caso mais completo
```

O v0.1 deve funcionar totalmente offline, com armazenamento local, exportacao em
arquivo unico e interface rapida para uso real durante atendimento de local.

## Principios

- Android-first, com foco inicial no Samsung S24 Ultra.
- Offline por padrao: sem login, servidor ou nuvem obrigatoria.
- Guia pericial, nao apenas formulario.
- Coleta rapida, com autosave.
- Fotos sempre categorizadas.
- Dados exportaveis para o SICRO desktop.
- Estrutura simples, auditavel e evolutiva.
- Recursos avancados ficam fora do v0.1: IA, OCR, LiDAR, nuvem, assinatura digital
  e sincronizacao automatica.

## Escopo v0.1

### Incluido

- Gestao de ocorrencias.
- Dados do caso.
- Captura de GPS automatico.
- Checklist contextual e editavel por ocorrencia.
- Relatorio de plantao em PDF.
- Telemetria operacional passiva por ocorrencia.
- Encerramento operacional formal com timeline automatica.
- Estatisticas locais agregadas por periodo, tipo de pericia e status.
- Relatorio estatistico operacional em PDF.
- Camera com categorias.
- Registro simples de veiculos.
- Registro simples de vitimas.
- Registro simples de vestigios.
- Medicoes manuais.
- Observacoes e notas.
- Exportacao `.sicroapp`.
- Importador no SICRO desktop.

### Fora do v0.1

- iOS.
- OCR de placas.
- IA de classificacao ou analise.
- LiDAR/ARCore/ARKit.
- Trena bluetooth.
- Sincronizacao em nuvem.
- Assinatura digital.
- Modulos fora de transito.
- Foto 360.
- Consulta externa de placas, BO ou sistemas institucionais.

## Fluxo de Uso

1. Perito abre o SICRO Operacional.
2. Cria uma nova ocorrencia ou continua uma ocorrencia em andamento.
3. Preenche dados basicos do caso.
4. Captura coordenada GPS do local.
5. Segue checklist guiado de transito.
6. Registra fotos por categoria.
7. Registra veiculos, vitimas, vestigios e medicoes relevantes.
8. Adiciona observacoes livres.
9. Encerra ou deixa a ocorrencia pendente.
10. Exporta o pacote `.sicroapp`.
11. No SICRO desktop, importa o pacote para criar ou enriquecer um caso.

## Telas Principais

### 1. Lista de Ocorrencias

Funcao: ponto inicial do app.

Conteudo:

- ocorrencias em andamento;
- pendentes;
- finalizadas;
- busca por BO, protocolo, placa, municipio e data;
- recentes/favoritos;
- botao de nova ocorrencia.

Acoes:

- abrir ocorrencia;
- duplicar ocorrencia;
- encerrar;
- exportar;
- excluir localmente, com confirmacao.

### 1.1 Estatisticas

Funcao: visao local agregada da producao registrada no aparelho.

Filtros:

- hoje;
- ultimos 7 dias;
- mes atual;
- ano atual;
- periodo personalizado;
- tipo de pericia;
- status operacional.

Indicadores:

- total de pericias;
- pericias concluidas;
- pericias exportadas;
- tempo medio de atendimento;
- totais de fotos, vestigios, medicoes, vitimas/corpos e veiculos;
- distribuicoes por tipo, natureza, mes, municipio e bairro;
- produtividade pessoal do periodo.

Acoes:

- gerar relatorio estatistico em PDF respeitando os filtros ativos;
- compartilhar ou salvar o PDF pelo Android.

### 2. Dashboard da Ocorrencia

Funcao: hub operacional do caso.

Blocos:

- Dados do caso;
- GPS/localizacao;
- Checklist;
- Fotos;
- Veiculos;
- Vitimas;
- Vestigios;
- Medicoes;
- Observacoes;
- Exportar.

Cada bloco deve exibir estado resumido, por exemplo:

- "GPS capturado";
- "12 fotos";
- "3 itens pendentes no checklist";
- "2 veiculos registrados".

### 3. Dados do Caso

Campos:

- BO;
- requisicao;
- protocolo;
- delegacia;
- municipio;
- bairro;
- logradouro;
- complemento/referencia;
- data/hora de acionamento;
- data/hora de chegada;
- data/hora de encerramento;
- peritos presentes;
- tecnico pericial;
- equipe policial/batalhao;
- comandante ou responsavel policial pela preservacao.

### 4. Localizacao

Campos e recursos:

- latitude;
- longitude;
- precisao em metros;
- altitude, se disponivel;
- timestamp da captura;
- origem: GPS/manual;
- botao "capturar novamente";
- campo de observacao do local.

Para v0.1, mapa offline completo nao e obrigatorio. O essencial e registrar a
coordenada e permitir edicao manual quando necessario.

### 5. Checklist de Transito

Funcao: guiar o perito para nao esquecer informacoes importantes.

Formato de item:

- pergunta;
- resposta: sim/nao/nao se aplica/nao verificado;
- observacao opcional;
- flag de obrigatorio.

Itens iniciais sugeridos:

- local isolado/preservado?
- vitimas removidas?
- veiculos removidos antes da chegada?
- pavimento molhado?
- iluminacao publica existente?
- iluminacao funcionando?
- semaforo existente?
- semaforo funcionando?
- sinalizacao vertical presente?
- sinalizacao horizontal presente?
- marcas de frenagem?
- marcas de arrasto?
- fragmentos/pecas no local?
- fluido/mancha biologica?
- vestigios removidos por terceiros?
- chuva no momento?
- visibilidade reduzida?

### 6. Fotos

Funcao: captura fotografica inteligente e organizada.

Categorias v0.1:

- visao geral;
- aproximacao;
- detalhe;
- veiculo;
- vitima;
- vestigio;
- sinalizacao;
- frenagem;
- semaforo;
- dano;
- documento;
- outros.

Metadados por foto:

- id;
- nome do arquivo;
- categoria;
- legenda;
- data/hora;
- latitude/longitude, se disponivel;
- hash SHA256;
- ocorrencia vinculada;
- entidade vinculada opcional: veiculo, vitima, vestigio ou medicao.

No v0.1, desenho sobre foto e anotacoes graficas podem ficar como recurso futuro.
Legenda textual ja e suficiente para o pacote inicial.

### 7. Veiculos

Campos:

- identificador: V1, V2, V3;
- placa;
- tipo;
- modelo;
- cor;
- sentido de trafego;
- posicao final descrita;
- avarias principais;
- condutor;
- proprietario;
- observacoes;
- fotos vinculadas.

### 8. Vitimas

Campos:

- identificador: P1, P2, P3;
- condicao: ilesa, lesionada, obito, desconhecida;
- removida: sim/nao;
- socorrida por;
- hospital/destino;
- posicao corporal descrita;
- uso de capacete/EPI;
- observacoes;
- fotos vinculadas.

### 9. Vestigios

Tipos iniciais:

- frenagem;
- arrasto;
- yaw;
- fragmentos;
- sangue;
- fluido;
- marca em poste;
- marca em arvore;
- dano urbano;
- peca;
- outro.

Campos:

- identificador;
- tipo;
- descricao;
- comprimento;
- unidade;
- direcao/sentido;
- localizacao textual;
- observacoes;
- fotos vinculadas.

### 10. Medicoes

Campos:

- identificador;
- ponto A;
- ponto B;
- valor;
- unidade;
- metodo;
- observacao;
- fotos vinculadas.

Exemplos:

- "V1 ate meio-fio";
- "inicio da frenagem ate posicao final";
- "largura da pista";
- "distancia entre veiculos".

### 11. Observacoes

Funcao: notas livres do perito.

Campos:

- texto;
- data/hora;
- categoria opcional;
- prioridade opcional.

Audio e voz-para-texto ficam fora do v0.1.

## Modelo de Dados

### Ocorrencia

```json
{
  "id": "uuid",
  "status": "em_andamento",
  "criado_em": "2026-05-19T10:30:00-03:00",
  "atualizado_em": "2026-05-19T11:10:00-03:00",
  "caso": {},
  "localizacao": {},
  "checklist": [],
  "fotos": [],
  "veiculos": [],
  "vitimas": [],
  "vestigios": [],
  "medicoes": [],
  "observacoes": []
}
```

### Foto

```json
{
  "id": "foto-uuid",
  "arquivo": "fotos/001_visao_geral.jpg",
  "categoria": "visao_geral",
  "legenda": "Vista geral do cruzamento no sentido bairro-centro.",
  "capturada_em": "2026-05-19T10:41:12-03:00",
  "gps": {
    "lat": 0.0349,
    "lon": -51.0694,
    "precisao_m": 6.2
  },
  "sha256": "..."
}
```

### Checklist Item

```json
{
  "id": "pavimento_molhado",
  "pergunta": "Pavimento molhado?",
  "resposta": "nao",
  "obrigatorio": true,
  "observacao": ""
}
```

## Estrutura do Arquivo `.sicroapp`

O arquivo `.sicroapp` e um ZIP renomeado.

```text
BO_1234_2026.sicroapp
├── manifest.json
├── caso.json
├── localizacao.json
├── checklist.json
├── fotos.json
├── veiculos.json
├── vitimas.json
├── vestigios.json
├── medicoes.json
├── observacoes.json
├── croqui_rapido.json
├── auditoria.json
├── hashes.json
└── fotos/
    ├── 001_visao_geral.jpg
    ├── 002_veiculo_v1.jpg
    └── 003_frenagem.jpg
```

### manifest.json

```json
{
  "formato": "sicroapp",
  "versao": "0.2",
  "gerado_em": "2026-05-19T12:00:00-03:00",
  "app": {
    "nome": "SICRO Operacional",
    "versao": "1.0.0-alpha"
  },
  "ocorrencia_id": "uuid",
  "bo": "1234/2026",
  "municipio": "Macapa",
  "total_fotos": 12,
  "sha256_manifest": null
}
```

### hashes.json

```json
{
  "algoritmo": "SHA256",
  "arquivos": [
    {
      "caminho": "caso.json",
      "sha256": "..."
    },
    {
      "caminho": "fotos/001_visao_geral.jpg",
      "sha256": "..."
    }
  ]
}
```

### auditoria.json

No v0.1, a auditoria e simples e local.

```json
[
  {
    "em": "2026-05-19T10:30:00-03:00",
    "acao": "ocorrencia_criada"
  },
  {
    "em": "2026-05-19T10:41:12-03:00",
    "acao": "foto_adicionada",
    "alvo": "foto-uuid"
  }
]
```

## Contrato de Importacao no SICRO Desktop

O SICRO desktop deve aceitar `.sicroapp` e oferecer duas opcoes:

1. Criar novo croqui a partir do pacote operacional.
2. Importar dados operacionais para um croqui existente.

### Dados importados imediatamente

- dados do caso;
- municipio/local/data/perito quando disponiveis;
- coordenada GPS;
- checklist;
- observacoes;
- lista de fotos;
- veiculos;
- vitimas;
- vestigios;
- medicoes.

### Como o desktop deve apresentar

Criar um painel ou popup "Dossie Operacional" com abas:

- Resumo;
- Fotos;
- Checklist;
- Veiculos;
- Vitimas;
- Vestigios;
- Medicoes;
- Observacoes.

### Sugestoes para o croqui

No v0.1, o importador nao precisa criar automaticamente todos os elementos no
canvas. Ele pode apenas disponibilizar os dados ao perito.

Opcionalmente, quando houver coordenada GPS, o SICRO desktop pode:

- preencher `_coord_osm`;
- sugerir abertura do Croqui por Coordenada;
- iniciar consulta OSM.

## Decisoes Tecnicas

### App mobile

- Tecnologia recomendada: Flutter.
- Plataforma inicial: Android.
- Persistencia local: banco local simples, como SQLite.
- Fotos: armazenadas no diretorio privado do app ate exportacao.
- Exportacao: ZIP gerado localmente com extensao `.sicroapp`.

### Desktop

- Importador em Python usando `zipfile` e `json`.
- Validacao de `manifest.json`.
- Validacao de versao `0.2`, mantendo leitura tolerante de `0.1`.
- Conferencia opcional de hashes.
- Copia/extração temporaria controlada das fotos para visualizacao.

## Roadmap Curto

### Etapa 1 - Contrato

- Finalizar esta especificacao.
- Criar exemplos reais de `.sicroapp`.
- Implementar importador minimo no SICRO desktop.

### Etapa 2 - App MVP

- Criar projeto Flutter.
- Implementar lista de ocorrencias.
- Implementar dados do caso e GPS.
- Implementar checklist.
- Implementar fotos categorizadas.
- Implementar exportacao `.sicroapp`.

### Etapa 3 - Dossie no Desktop

- Abrir `.sicroapp`.
- Exibir resumo e fotos.
- Preencher dados do caso.
- Permitir consulta do material durante a montagem do croqui.

### Etapa 4 - Entidades

- Veiculos.
- Vitimas.
- Vestigios.
- Medicoes.

## Critério de Sucesso v0.1

O v0.1 esta pronto quando for possivel:

1. Criar uma ocorrencia no celular.
2. Capturar dados do caso, GPS, checklist e fotos categorizadas.
3. Exportar um `.sicroapp`.
4. Abrir esse arquivo no SICRO desktop.
5. Consultar o Dossie Operacional enquanto o croqui e produzido.
