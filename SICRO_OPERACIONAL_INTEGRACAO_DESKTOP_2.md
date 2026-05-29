# SICRO Operacional - Integracao com SICRO Desktop 2.0

Status da auditoria: 2026-05-25.

Projeto auditado: `C:\Projetos\SICRO_CAMPO`.

Escopo deste documento: leitura tecnica do app Flutter atual, auditoria do pacote `.sicroapp` e proposta de contrato para importacao no SICRO Desktop 2.0, previsto em Tauri + React + TypeScript + Rust + SQLite.

Este documento nao altera codigo e nao implementa importador. Ele diferencia:

- **Existe hoje**: encontrado no codigo atual do SICRO Operacional.
- **Proposto**: recomendacao para o contrato oficial e para o Desktop 2.0.
- **Necessario para SICRO 2.0**: ajuste ou decisao antes da integracao completa.

## 1. Visao geral do SICRO Operacional

O SICRO Operacional e o aplicativo mobile de campo do ecossistema SICRO. Sua funcao e registrar, em modo offline, o dossie operacional de uma pericia: dados do caso, classificacao do tipo de pericia, GPS, fotos categorizadas, checklist, entidades, vestigios, medicoes, observacoes, timeline, estatisticas e pacote exportavel.

Fluxos cobertos hoje:

- onboarding inicial com perfil do perito e areas ativas;
- tela inicial em formato de diario operacional;
- iniciar pericia por area;
- criacao de ocorrencia com metadados por tipo de pericia;
- preenchimento dos dados do caso;
- GPS manual e GPS operacional continuo enquanto a pericia esta ativa;
- captura de fotos pela camera;
- categorizacao e persistencia de fotos;
- checklist contextual por tipo de pericia, editavel na ocorrencia;
- registro de veiculos;
- registro de vitimas/corpos;
- registro de vestigios;
- registro de medicoes;
- registro de observacoes/notas;
- vinculacao de fotos a veiculos, vitimas, vestigios e medicoes;
- encerramento operacional da pericia;
- estatisticas locais agregadas;
- relatorio estatistico em PDF;
- relatorio de plantao em PDF;
- exportacao `.sicroapp`;
- recebimento, validacao e importacao de `.sicroapp` no proprio mobile.

Tipos de pericia existentes hoje:

- Transito;
- Local de crime, com codigo contratual legado `morte_violenta`;
- Patrimonio;
- Ambiental;
- Balistica Forense;
- Audio e Imagem;
- Papiloscopia.

Dados coletados hoje:

- dados administrativos do caso;
- municipio, bairro, logradouro e referencia;
- equipe pericial, tecnico pericial, equipe policial e comandante policial;
- tipo de pericia, natureza, resultado e metadados especificos;
- localizacao principal;
- trilha de leituras GPS;
- fotos categorizadas;
- checklist com respostas, observacoes, obrigatoriedade e origem;
- veiculos;
- vitimas/corpos;
- vestigios;
- medicoes;
- observacoes/notas;
- status operacional;
- modulos nao aplicaveis;
- timeline automatica;
- estatisticas derivadas.

Telas/modulos existentes no codigo atual:

- `OnboardingScreen`;
- `HomeScreen`;
- `StartExpertiseScreen`;
- telas de configuracao inicial por area: transito, local de crime, patrimonio, ambiental, balistica, audio/imagem e papiloscopia;
- `OccurrenceListScreen`;
- `OccurrenceDashboardScreen`;
- `CaseDataScreen`;
- `LocationScreen`;
- `PhotosScreen`;
- `ChecklistScreen`;
- `VehiclesScreen`;
- `VictimsScreen`;
- `TracesScreen`;
- `MeasurementsScreen`;
- `NotesScreen`;
- `OccurrenceClosureScreen`;
- `StatisticsScreen`;
- `DutyReportScreen`;
- `SicroPackageReceivedScreen`;
- `SettingsScreen`.

Estado atual da implementacao:

- app Flutter Android-first funcional;
- versao do app em `AppInfo`: `SICRO Operacional 1.0.0-alpha+1`;
- armazenamento local em JSON no sandbox do app;
- pacote `.sicroapp` atual versionado como `0.7`;
- importacao mobile de `.sicroapp` implementada;
- compatibilidade iOS parcialmente preparada por `Info.plist`, mas sem validacao final de build/TestFlight neste documento;
- desktop importador ainda nao implementado.

Arquivos/pastas principais do projeto:

```text
C:\Projetos\SICRO_CAMPO
|-- lib/
|   |-- app/
|   |-- core/
|   |   |-- data/
|   |   |-- services/
|   |-- domain/
|   |   |-- models/
|   |-- features/
|-- android/
|-- ios/
|-- assets/
|-- docs/
|-- test/
|-- pubspec.yaml
```

## 2. Stack e estrutura tecnica atual

Existe hoje:

- linguagem principal: Dart;
- framework: Flutter;
- UI: MaterialApp com tema institucional escuro;
- estado local: `ChangeNotifier`, repositorios em memoria e persistencia em arquivo;
- armazenamento: `path_provider` + JSON em `getApplicationDocumentsDirectory()`;
- camera: `image_picker`;
- localizacao/GPS: `geolocator`;
- hash: `crypto`;
- ZIP: `archive`;
- compartilhamento: `share_plus`;
- PDF: `pdf`;
- Android native channel para receber pacotes externos: `MethodChannel`.

Dependencias relevantes em `pubspec.yaml`:

```text
path_provider: ^2.1.5
geolocator: ^14.0.2
image_picker: ^1.2.2
crypto: ^3.0.7
archive: ^4.0.9
share_plus: ^12.0.2
pdf: ^3.12.0
```

Estrutura de pastas:

- `lib/app`: bootstrap, tema e informacoes do app.
- `lib/core/data`: repositorios, storage, exportacao, importacao, PDF e estatisticas.
- `lib/core/services`: camera, GPS, pacote externo e sessao operacional.
- `lib/domain/models`: modelos serializaveis.
- `lib/features`: telas/modulos da interface.
- `docs`: especificacoes, politicas e notas.
- `android`: configuracao Android, permissoes e intent-filters.
- `ios`: configuracao iOS inicial.
- `test`: testes unitarios/widget existentes.

Servicos principais:

- `OccurrenceRepository`: cria, atualiza, importa, exclui e persiste ocorrencias.
- `FileOccurrenceStorage`: salva `occurrences.json`.
- `AppSettingsRepository`: gerencia perfil do perito e areas ativas.
- `FileAppSettingsStorage`: salva `settings.json`.
- `PhotoFileStorage`: copia fotos capturadas/importadas para pasta privada e calcula hash.
- `LocationCaptureService`: solicita permissao e captura posicao.
- `OperationalSessionTracker`: acompanha ocorrencia ativa e salva leituras GPS periodicas.
- `SicroCampoExportService`: gera pacote `.sicroapp`.
- `SicroAppImportService`: valida e importa pacote `.sicroapp` no proprio mobile.
- `ExternalPackageChannel`: recebe arquivos `.sicroapp` abertos pelo Android.
- `OperationalStatisticsService`: agrega estatisticas locais.
- `DutyReportPdfService`: gera relatorio de plantao em PDF.
- `StatisticalReportPdfService`: gera relatorio estatistico em PDF.

Armazenamento local:

- ocorrencias: `sicro_campo/occurrences.json`;
- configuracoes: `sicro_campo/settings.json`;
- fotos: `sicro_campo/photos/<occurrenceId>/<photoId>.<ext>`;
- exportacoes: `sicro_operacional/exports/<arquivo>.sicroapp`.

Manipulacao de fotos/arquivos:

- fotos sao capturadas por camera via `image_picker`;
- sao copiadas para armazenamento privado do app;
- recebem ID `foto_<microsecondsSinceEpoch>`;
- recebem hash local em base64url no `PhotoFileStorage`;
- na exportacao, sao copiadas para `fotos/<id>.<ext>` dentro do ZIP;
- em `fotos.json`, o caminho exportado passa a ser relativo ao pacote.

Uso de GPS/localizacao:

- `LocationCaptureService.ensureReady()` valida servico e permissao;
- captura manual usa `getCurrentPosition`;
- captura continua usa `getPositionStream`;
- GPS operacional salva leituras a cada 30 segundos ou sempre que houver leitura melhor;
- coordenada principal e a melhor leitura quando aplicavel.

Geracao de pacote `.sicroapp`:

- existe hoje em `SicroCampoExportService`;
- formato real e ZIP renomeado;
- inclui JSONs estruturados, pasta `fotos/` e `hashes.json`;
- versao atual do contrato: `0.7`;
- extensao oficial: `.sicroapp`;
- extensao legada aceita: `.sicrocampo`.

Importacao `.sicroapp` no mobile:

- existe hoje;
- recebe arquivo pelo Android via intent + method channel;
- copia/recebe arquivo externo;
- valida ZIP;
- valida manifest;
- valida hashes quando possivel;
- exibe resumo;
- importa como nova ocorrencia local editavel;
- copia fotos do pacote para armazenamento privado;
- preserva IDs das fotos quando possivel.

## 3. Modelos de dominio existentes

### `FieldOccurrence`

Arquivo: `lib/domain/models/occurrence.dart`.

Modelo central da ocorrencia/dossie.

Campos:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | `String` | Sim | ID local da ocorrencia. |
| `createdAt` | `DateTime` | Sim | Criacao. |
| `updatedAt` | `DateTime` | Sim | Ultima atualizacao. |
| `metadata` | `ForensicCaseMetadata` | Sim | Tipo/natureza/metadados. |
| `status` | `OccurrenceStatus` | Sim | Status operacional. |
| `startedAt` | `DateTime?` | Opcional | Inicio da sessao. |
| `finishedAt` | `DateTime?` | Opcional | Conclusao. |
| `exportedAt` | `DateTime?` | Opcional | Ultima exportacao. |
| `exportedPackageName` | `String` | Opcional | Nome do pacote exportado. |
| `exportedPackageSha256` | `String` | Opcional | SHA-256 do pacote. |
| `notApplicableItems` | `List<String>` | Sim | Modulos marcados como nao aplicaveis. |
| `caseData` | `CaseData` | Sim | Dados administrativos. |
| `location` | `LocationRecord` | Sim | Coordenada principal. |
| `gpsTrack` | `List<LocationRecord>` | Sim | Leituras GPS. |
| `checklist` | `List<ChecklistItem>` | Sim | Checklist final da ocorrencia. |
| `photos` | `List<FieldPhoto>` | Sim | Fotos. |
| `vehicles` | `List<VehicleRecord>` | Sim | Veiculos. |
| `victims` | `List<VictimRecord>` | Sim | Vitimas/corpos. |
| `traces` | `List<TraceRecord>` | Sim | Vestigios. |
| `measurements` | `List<MeasurementRecord>` | Sim | Medicoes. |
| `notes` | `List<FieldNote>` | Sim | Observacoes. |
| `timeline` | `List<OccurrenceTimelineEvent>` | Sim | Eventos automaticos. |

Relacionamentos:

- `photos[].id` e referenciado por `vehicles[].photoIds`, `victims[].photoIds`, `traces[].photoIds`, `measurements[].photoIds`;
- `notApplicableItems` influencia progresso operacional;
- `metadata.type` define fluxo, checklist base e dashboard contextual.

### `OccurrenceStatus`

Arquivo: `lib/domain/models/occurrence.dart`.

Valores:

- `em_andamento`;
- `concluida`;
- `exportada`;
- `pendente_revisao`;
- `incompleta`;
- `arquivada`.

Compatibilidade:

- aceita codigos legados como `em_atendimento`, `pendente`, `finalizada`, `coleta_parcial`, `coleta_concluida`.

### `ForensicCaseMetadata`

Arquivo: `lib/domain/models/forensic_case_metadata.dart`.

Campos transversais:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `type` | `ForensicCaseType` | Sim | Tipo de pericia. |
| `trafficNature` | `TrafficNature?` | Condicional | Transito. |
| `trafficInvolved` | `List<TrafficInvolved>` | Sim | Usado sobretudo em transito. |
| `officialVehicleInvolved` | `bool` | Sim | Exportado como `veiculo_oficial`; marca atendimento envolvendo carro/veiculo oficial. |
| `result` | `OccurrenceResult` | Sim | Resultado transversal. |
| `violentDeathNature` | `ViolentDeathNature?` | Condicional | Local de crime. |
| `bodyState` | `BodyState?` | Condicional | Local de crime. |
| `victimCount` | `VictimCount?` | Condicional | Local de crime. |
| `sceneEnvironment` | `SceneEnvironment?` | Condicional | Local de crime. |
| `expectedViolentDeathTraces` | `List<ExpectedViolentDeathTrace>` | Condicional | Local de crime. |
| `propertyNature` | `PropertyNature?` | Condicional | Patrimonio. |
| `environmentalNature` | `EnvironmentalNature?` | Condicional | Ambiental. |
| `environmentalContext` | `EnvironmentalSceneContext?` | Condicional | Ambiental. |
| `expectedEnvironmentalEvidences` | `List<ExpectedEnvironmentalEvidence>` | Condicional | Ambiental. |
| `ballisticsNature` | `BallisticsNature?` | Condicional | Balistica. |
| `ballisticsContext` | `BallisticsContext?` | Condicional | Balistica. |
| `expectedBallisticEvidences` | `List<ExpectedBallisticEvidence>` | Condicional | Balistica. |
| `audioImageNature` | `AudioImageNature?` | Condicional | Audio e imagem. |
| `audioImageContext` | `AudioImageContext?` | Condicional | Audio e imagem. |
| `expectedAudioImageEvidences` | `List<ExpectedAudioImageEvidence>` | Condicional | Audio e imagem. |
| `papiloscopyNature` | `PapiloscopyNature?` | Condicional | Papiloscopia. |
| `papiloscopyContext` | `PapiloscopyContext?` | Condicional | Papiloscopia. |
| `expectedPapiloscopyEvidences` | `List<ExpectedPapiloscopyEvidence>` | Condicional | Papiloscopia. |

JSON:

- sempre exporta `tipo_pericia`, `natureza`, `envolvidos`, `resultado`, `resumo`;
- exporta subobjeto condicional com o mesmo codigo do tipo de pericia, exceto o legado `morte_violenta`, cujo rotulo de UI e "Local de crime".

### `CaseData`

Arquivo: `lib/domain/models/case_data.dart`.

Campos:

| Campo Dart | Chave JSON | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- | --- |
| `bo` | `bo` | `String` | Opcional | BO. |
| `requisition` | `requisicao` | `String` | Opcional | Requisicao/oficio. |
| `protocol` | `protocolo` | `String` | Opcional | Protocolo. |
| `policeUnit` | `delegacia` | `String` | Opcional | Delegacia/unidade. |
| `municipality` | `municipio` | `String` | Opcional | Municipio. |
| `district` | `bairro` | `String` | Opcional | Bairro. |
| `street` | `logradouro` | `String` | Opcional | Logradouro. |
| `reference` | `referencia` | `String` | Opcional | Referencia. |
| `peritians` | `peritos` | `String` | Opcional | Peritos. |
| `supportTeam` | `tecnico_pericial` | `String` | Opcional | Tecnico pericial. |
| `supportTeam` | `equipe_apoio` | `String` | Opcional | Alias legado preservado. |
| `policeTeam` | `equipe_policial` | `String` | Opcional | Batalhao/equipe policial. |
| `policeCommander` | `comandante_policial` | `String` | Opcional | Responsavel policial. |
| `calledAt` | `acionamento_em` | `DateTime?` | Opcional | ISO-8601. |
| `arrivedAt` | `chegada_em` | `DateTime?` | Opcional | ISO-8601. |
| `closedAt` | `encerramento_em` | `DateTime?` | Opcional | ISO-8601. |

### `LocationRecord`

Arquivo: `lib/domain/models/location_record.dart`.

Campos:

- `latitude`: `double?`;
- `longitude`: `double?`;
- `accuracyMeters`: `double?`, JSON `precisao_m`;
- `altitudeMeters`: `double?`, JSON `altitude_m`;
- `capturedAt`: `DateTime?`, JSON `capturado_em`;
- `source`: `String`, JSON `origem`, padrao `gps`;
- `note`: `String`, JSON `observacao`.

Relacionamento:

- `FieldOccurrence.location` e a coordenada principal;
- `FieldOccurrence.gpsTrack` e a lista de leituras.

### `FieldPhoto`

Arquivo: `lib/domain/models/field_photo.dart`.

Campos:

| Campo Dart | Chave JSON | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- | --- |
| `id` | `id` | `String` | Sim | ID da foto. |
| `filePath` | `arquivo` | `String` | Sim | Local: caminho privado; pacote: caminho relativo. |
| `category` | `categoria` | `PhotoCategory` | Sim | Categoria. |
| `capturedAt` | `capturada_em` | `DateTime` | Sim | ISO-8601. |
| `caption` | `legenda` | `String` | Opcional | Legenda. |
| `sha256` | `sha256` | `String` | Opcional | Hash. |
| `linkedEntityId` | `entidade_vinculada` | `String?` | Opcional | Viculo simples legado/futuro. |

Categorias atuais:

- `visao_geral`;
- `aproximacao`;
- `detalhe`;
- `veiculo`;
- `vitima`;
- `vestigio`;
- `sinalizacao`;
- `frenagem`;
- `semaforo`;
- `dano`;
- `documento`;
- `outros`.

### `ChecklistItem`

Arquivo: `lib/domain/models/checklist_item.dart`.

Campos:

- `id`: `String`;
- `category`: `ChecklistCategory`, JSON `categoria`;
- `question`: `String`, JSON `pergunta`;
- `required`: `bool`, JSON `obrigatorio`;
- `answer`: `ChecklistAnswer`, JSON `resposta`;
- `note`: `String`, JSON `observacao`;
- `defaultNote`: `String`, JSON `observacao_padrao`;
- `origin`: `ChecklistItemOrigin`, JSON `origem`.

Respostas:

- `nao_verificado`;
- `sim`;
- `nao`;
- `nao_se_aplica`.

Origem:

- `base`;
- `adicionado`.

O checklist e contextual por tipo de pericia e editavel por ocorrencia.

### `VehicleRecord`

Arquivo: `lib/domain/models/vehicle_record.dart`.

Campos:

- `id`: `String`;
- `identifier`: `String`, exemplo `V1`;
- `plate`: `String`;
- `type`: `String`;
- `model`: `String`;
- `color`: `String`;
- `trafficDirection`: `String`;
- `finalPosition`: `String`;
- `impactPoint`: `String`, JSON `ponto_impacto`;
- `damage`: `String`;
- `driver`: `String`;
- `owner`: `String`;
- `note`: `String`;
- `photoIds`: `List<String>`, JSON `fotos`.

### `VictimRecord`

Arquivo: `lib/domain/models/victim_record.dart`.

Campos:

- `id`: `String`;
- `identifier`: `String`, exemplo `P1`;
- `name`: `String`;
- `condition`: `VictimCondition`;
- `type`: `VictimType`;
- `removalStatus`: `VictimRemovalStatus`;
- `rescuedBy`: `String`;
- `destination`: `String`;
- `removedAt`: `DateTime?`;
- `bodyPosition`: `String`;
- `protectiveEquipment`: `String`;
- `note`: `String`;
- `photoIds`: `List<String>`.

Valores principais:

- condicao: `ilesa`, `lesionada`, `obito`, `desconhecida`;
- tipo: `condutor`, `passageiro`, `pedestre`, `ciclista`, `motociclista`, `outro`;
- remocao: `sim`, `nao`, `nao_informado`.

### `TraceRecord`

Arquivo: `lib/domain/models/trace_record.dart`.

Campos:

- `id`: `String`;
- `identifier`: `String`, exemplo `E1`;
- `type`: `TraceType`;
- `description`: `String`;
- `length`: `double?`;
- `width`: `double?`;
- `unit`: `String`, padrao `m`;
- `direction`: `String`;
- `locationDescription`: `String`, JSON `localizacao_textual`;
- `note`: `String`;
- `photoIds`: `List<String>`;
- `sketchElementIds`: `List<String>`, JSON `croqui`.

Tipos atuais incluem transito, local de crime, patrimonio, ambiental, balistica, audio/imagem e papiloscopia. Exemplos:

- `frenagem`, `derrapagem`, `arrasto`, `fragmento`, `mancha`, `sulco`, `pneu`, `fluido`, `peca_desprendida`, `marca_impacto`;
- `sangue`, `vestigio_biologico`, `capsula_estojo`, `projetil`, `perfuracao`, `arma_branca`, `arma_fogo`, `sinal_luta`, `pegada`, `objeto_deslocado`;
- `dano`, `marca_ferramenta`, `rompimento`, `fechadura`, `porta_janela`, `foco_provavel_incendio`, `padrao_queima`, `dano_termico`, `fuligem_residuo`;
- `supressao_vegetal`, `efluente`, `indicador_queima`, `cadaver_animal`, `amostra_ambiental`;
- `cartucho_municao`, `padrao_balistico`, `amostra_gsr`;
- `arquivo_multimidia`, `equipamento_cftv`, `midia_armazenamento`, `registro_audio`, `registro_video`, `registro_imagem`;
- `impressao_latente`, `impressao_patente`, `impressao_moldada`, `registro_datiloscopico`, `registro_palmar`, `fragmento_papilar`, `registro_necropapiloscopico`.

### `MeasurementRecord`

Arquivo: `lib/domain/models/measurement_record.dart`.

Campos:

- `id`: `String`;
- `label`: `String`, JSON `rotulo`;
- `pointA`: `String`, JSON `ponto_a`;
- `pointB`: `String`, JSON `ponto_b`;
- `value`: `double`, JSON `valor`;
- `unit`: `String`, JSON `unidade`;
- `method`: `String`, JSON `metodo`;
- `note`: `String`, JSON `observacao`;
- `photoIds`: `List<String>`, JSON `fotos`;
- `sketchElementIds`: `List<String>`, JSON `croqui`.

### `FieldNote`

Arquivo: `lib/domain/models/field_note.dart`.

Campos:

- `id`: `String`;
- `text`: `String`, JSON `texto`;
- `category`: `NoteCategory`, JSON `categoria`;
- `priority`: `NotePriority`, JSON `prioridade`;
- `createdAt`: `DateTime`, JSON `criado_em`;
- `updatedAt`: `DateTime`, JSON `editado_em`.

Categorias:

- `geral`, `local`, `veiculo`, `vitima`, `vestigio`, `dinamica`, `pendencia`, `outro`.

Prioridades:

- `normal`, `importante`, `critica`.

### `OccurrenceTimelineEvent`

Arquivo: `lib/domain/models/occurrence.dart`.

Campos:

- `id`: `String`;
- `type`: `OccurrenceTimelineEventType`;
- `occurredAt`: `DateTime`;
- `title`: `String`;
- `description`: `String`.

Tipos:

- `ocorrencia_criada`;
- `gps_iniciado`;
- `gps_capturado`;
- `primeira_foto`;
- `exportacao`;
- `importacao`;
- `conclusao`;
- `reabertura`;
- `status_alterado`;
- `arquivamento`.

### `OccurrenceStats`

Arquivo: `lib/domain/models/occurrence.dart`.

Estatisticas derivadas da ocorrencia, nao preenchidas manualmente.

Campos principais:

- `occurrenceId`;
- `forensicType`;
- `nature`;
- `result`;
- `occurrenceStatus`;
- `operationalStatus`;
- `createdAt`;
- `startedAt`;
- `finishedAt`;
- `durationSeconds`;
- `municipality`;
- `district`;
- `address`;
- `primaryCoordinate`;
- `bestGpsAccuracyMeters`;
- contagens de fotos, vitimas, veiculos, vestigios, medicoes, observacoes e checklist;
- `exported`;
- `exportedAt`.

### `AppSettings` e `ExpertProfile`

Arquivos:

- `lib/domain/models/app_settings.dart`;
- `lib/core/data/app_settings_storage.dart`.

`ExpertProfile`:

- `name`, JSON `nome`;
- `role`, JSON `cargo`;
- `registration`, JSON `matricula`;
- `organization`, JSON `orgao`;
- `unit`, JSON `unidade`.

`AppSettings`:

- `onboardingCompleted`;
- `profile`;
- `activeAreas`.

Observacao importante: perfil global do perito existe no armazenamento local, mas nao foi encontrado exportado no `.sicroapp` atual.

### Assinatura

Nao encontrado no codigo atual.

### Anexos genericos

Nao encontrado no codigo atual como modelo proprio. O app possui fotos e tipos de vestigio que representam arquivos/midias em audio e imagem, mas nao ha modelo generico `Attachment`.

### Video e audio capturados pelo app

Nao encontrado no codigo atual como captura binaria. Existem tipos de vestigio/midia (`registro_audio`, `registro_video`, `arquivo_multimidia`), mas o pacote atual inclui apenas fotos na pasta `fotos/`.

## 4. Fluxo de dados da ocorrencia

### 1. Criacao da ocorrencia

Implementado em `OccurrenceRepository.createOccurrence`.

Fluxo:

- usuario passa pelo `StartExpertiseScreen`;
- escolhe area/tipo de pericia;
- telas especificas montam `ForensicCaseMetadata`;
- repositorio cria `FieldOccurrence`;
- define `id`, `createdAt`, `updatedAt`, `startedAt`;
- cria checklist base via `defaultChecklistFor(metadata)`;
- adiciona eventos de timeline `ocorrencia_criada` e `gps_iniciado`;
- salva no storage local.

### 2. Preenchimento dos dados

Implementado em:

- `CaseDataScreen`;
- `OccurrenceRepository.updateCaseData`.

Os dados sao salvos em `FieldOccurrence.caseData` e persistidos em `occurrences.json`.

### 3. Captura de fotos

Implementado em:

- `PhotosScreen`;
- `PhotoCaptureService`;
- `PhotoFileStorage`;
- `OccurrenceRepository.addPhoto`.

Fluxo:

- abre camera;
- captura `XFile`;
- escolhe categoria;
- copia arquivo para pasta privada da ocorrencia;
- calcula SHA local;
- cria `FieldPhoto`;
- adiciona no dossie;
- se for primeira foto, adiciona evento `primeira_foto`.

### 4. Checklist

Implementado em:

- `ChecklistScreen`;
- `OccurrenceRepository.updateChecklistItem`;
- `OccurrenceRepository.addChecklistItem`;
- `OccurrenceRepository.updateChecklistQuestion`;
- `OccurrenceRepository.removeChecklistItem`.

Fluxo:

- checklist base nasce com a ocorrencia;
- perguntas podem ser respondidas, adicionadas, editadas e excluidas;
- respostas e observacoes sao persistidas;
- checklist final entra em `checklist.json`.

### 5. Vestigios, veiculos, vitimas e medicoes

Implementado em:

- `VehiclesScreen`;
- `VictimsScreen`;
- `TracesScreen`;
- `MeasurementsScreen`;
- metodos `create/update/remove` do `OccurrenceRepository`.

Vinculos de fotos sao listas de IDs, sem duplicacao de arquivos.

### 6. Salvamento local

Implementado em:

- `FileOccurrenceStorage.saveOccurrences`.

Formato local:

```json
{
  "formato": "sicrocampo_local_store",
  "versao": "0.1",
  "salvo_em": "2026-05-25T10:00:00.000",
  "ocorrencias": []
}
```

### 7. Exportacao

Implementado em:

- `SicroCampoExportService.exportOccurrence`.

Fluxo:

- cria copia da ocorrencia com status `exportada`;
- monta ZIP em memoria;
- adiciona pasta `fotos/`;
- copia fotos existentes;
- monta JSONs;
- gera `manifest.json`;
- gera `hashes.json`;
- grava arquivo `.sicroapp`;
- retorna tamanho, SHA do pacote, contagens e avisos.

### 8. Estrutura final gerada

Existe hoje e esta detalhada na secao 5.

## 5. Estrutura atual do pacote `.sicroapp`

Existe hoje.

Formato real: ZIP renomeado com extensao `.sicroapp`.

Versao atual: `0.7`.

Contrato no codigo: `SicroCampoPackageContract`.

Estrutura gerada hoje:

```text
SICRO_OPERACIONAL_<identificador>_<timestamp>.sicroapp
|-- manifest.json
|-- metadados.json
|-- caso.json
|-- localizacao.json
|-- gps_leituras.json
|-- estatisticas.json
|-- timeline.json
|-- checklist.json
|-- fotos.json
|-- veiculos.json
|-- vitimas.json
|-- vestigios.json
|-- medicoes.json
|-- observacoes.json
|-- operacional.json
|-- hashes.json
|-- fotos/
    |-- <id_da_foto>.jpg
    |-- <id_da_foto>.png
    |-- <id_da_foto>.webp
```

Arquivos reservados no contrato, mas nao gerados hoje:

- `croqui_rapido.json`;
- `auditoria.json`.

Relatorios de plantao e relatorios estatisticos em PDF nao entram no `.sicroapp` atual. Sao arquivos separados.

### `manifest.json`

Finalidade: cabecalho do pacote, versao, compatibilidade, resumo da ocorrencia, contagens, arquivos e avisos.

Exemplo realista:

```json
{
  "formato": "sicroapp",
  "formatos_compativeis": ["sicroapp", "sicrocampo"],
  "extensoes_compativeis": [".sicroapp", ".sicrocampo"],
  "versao": "0.7",
  "versoes_compativeis": ["0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7"],
  "gerado_em": "2026-05-25T14:30:10.000",
  "ocorrencia": {
    "id": "occ_123",
    "status": "exportada",
    "status_operacional": "exportada",
    "iniciado_em": "2026-05-25T13:10:00.000",
    "concluido_em": "2026-05-25T14:20:00.000",
    "duracao_segundos": 4200,
    "tipo_pericia": "transito",
    "natureza": "colisao",
    "resultado": "vitima_lesionada",
    "criado_em": "2026-05-25T13:05:00.000",
    "atualizado_em": "2026-05-25T14:29:00.000"
  },
  "contagens": {
    "checklist": 24,
    "timeline": 5,
    "fotos": 18,
    "leituras_gps": 12,
    "veiculos": 2,
    "vitimas": 1,
    "vestigios": 3,
    "medicoes": 4,
    "observacoes": 2
  },
  "arquivos": ["manifest.json", "metadados.json", "caso.json", "hashes.json"],
  "avisos": []
}
```

Campos obrigatorios: `formato`, `versao`, `gerado_em`, `ocorrencia`, `contagens`, `arquivos`, `avisos`.

### `metadados.json`

Finalidade: tipo de pericia, natureza, resultado e subobjeto especifico.

Campos comuns:

- `tipo_pericia`: string;
- `natureza`: string ou null;
- `envolvidos`: lista de string;
- `resultado`: string;
- `resumo`: string.

Subobjetos condicionais atuais:

- `morte_violenta`;
- `patrimonio`;
- `ambiental`;
- `balistica_forense`;
- `audio_imagem`;
- `papiloscopia`.

Nota: a UI chama `morte_violenta` de "Local de crime", mas o codigo contratual foi preservado para compatibilidade.

### `caso.json`

Finalidade: dados administrativos e local textual.

Campos:

- `bo`;
- `requisicao`;
- `protocolo`;
- `delegacia`;
- `municipio`;
- `bairro`;
- `logradouro`;
- `referencia`;
- `peritos`;
- `tecnico_pericial`;
- `equipe_apoio`;
- `equipe_policial`;
- `comandante_policial`;
- `acionamento_em`;
- `chegada_em`;
- `encerramento_em`.

Compatibilidade importante: `equipe_apoio` continua sendo exportado como alias legado de `tecnico_pericial`.

### `localizacao.json`

Finalidade: coordenada principal.

Campos:

- `latitude`: numero ou null;
- `longitude`: numero ou null;
- `precisao_m`: numero ou null;
- `altitude_m`: numero ou null;
- `capturado_em`: string ISO-8601 ou null;
- `origem`: string;
- `observacao`: string.

### `gps_leituras.json`

Finalidade: lista de leituras GPS da sessao operacional.

Formato: lista de objetos `LocationRecord`.

Pode ser `[]`.

### `fotos.json` e `fotos/`

Finalidade: indice de fotos e binarios.

Na exportacao, cada foto recebe:

- `id`;
- `arquivo`: caminho relativo, exemplo `fotos/foto_123.jpg`;
- `categoria`;
- `capturada_em`;
- `legenda`;
- `sha256`;
- `sha256_original`;
- `entidade_vinculada`;
- `arquivo_disponivel`.

Se o arquivo local original nao for encontrado:

- a foto ainda pode aparecer em `fotos.json`;
- `arquivo_disponivel` sera `false`;
- o binario nao entra no ZIP;
- `manifest.avisos` registra a ausencia.

### `checklist.json`

Finalidade: checklist final da ocorrencia.

Cada item:

- `id`;
- `categoria`;
- `pergunta`;
- `obrigatorio`;
- `resposta`;
- `observacao`;
- `observacao_padrao`;
- `origem`.

### `veiculos.json`

Lista de `VehicleRecord`, incluindo `ponto_impacto` e `fotos`.

### `vitimas.json`

Lista de `VictimRecord`, incluindo condicao, tipo, remocao e `fotos`.

### `vestigios.json`

Lista de `TraceRecord`, incluindo tipo, descricao, dimensoes, direcao, localizacao textual, observacao, `fotos` e `croqui`.

### `medicoes.json`

Lista de `MeasurementRecord`, incluindo pontos A/B, valor, unidade, metodo, observacao, `fotos` e `croqui`.

### `observacoes.json`

Lista de `FieldNote`.

### `timeline.json`

Lista de eventos automaticos.

### `estatisticas.json`

Objeto de estatisticas derivadas da ocorrencia.

Campos principais:

- `ocorrencia_id`;
- `tipo_pericia`;
- `natureza`;
- `resultado`;
- `status_ocorrencia`;
- `status_operacional`;
- `criado_em`;
- `iniciado_em`;
- `concluido_em`;
- `duracao_segundos`;
- `municipio`;
- `bairro`;
- `endereco`;
- `coordenada_principal`;
- `melhor_precisao_gps_m`;
- totais de fotos, vitimas/corpos, veiculos, vestigios, medicoes, observacoes;
- totais de checklist;
- itens nao aplicaveis;
- `exportada`;
- `ultima_exportacao_em`;
- `leituras_gps`;
- `distancia_aproximada_m`;
- `pendencias_encerramento`.

### `operacional.json`

Objeto com:

- `percentual`;
- `itens_concluidos`;
- `itens_totais`;
- `pendencias`;
- `nao_aplicavel`;
- `fluxo_sugerido`;
- `modulos`;
- `sessao`.

### `hashes.json`

Objeto:

```json
{
  "algoritmo": "SHA-256",
  "arquivos": [
    {
      "caminho": "caso.json",
      "sha256": "..."
    }
  ],
  "observacao": "hashes.json nao inclui o proprio arquivo para evitar referencia circular."
}
```

O `hashes.json` nao inclui hash de si mesmo.

## 6. Proposta oficial de contrato `.sicroapp`

O pacote atual ja e utilizavel. Para o SICRO Desktop 2.0, a recomendacao e manter compatibilidade com a estrutura atual, mas criar uma camada de interpretacao interna mais generica no Desktop.

### Estrutura proposta canonica para o futuro

```text
ocorrencia.sicroapp
  manifest.json
  occurrence.json
  entities.json
  checklist.json
  measurements.json
  traces.json
  media_index.json
  timeline.json
  stats.json
  hashes.json
  media/
    photos/
    videos/
    audio/
    attachments/
```

Importante: isto e uma proposta futura. O app atual exporta nomes em portugues (`caso.json`, `fotos.json`, `vestigios.json`). Para nao quebrar compatibilidade, o Desktop 2.0 deve importar a estrutura atual primeiro. A estrutura canonica acima pode ser adotada como formato `1.0` apenas quando mobile e desktop estiverem sincronizados.

### Mapeamento entre estrutura atual e canonica proposta

| Atual `.sicroapp 0.7` | Canonico futuro | Observacao |
| --- | --- | --- |
| `manifest.json` | `manifest.json` | Manter. |
| `metadados.json` + `caso.json` + `localizacao.json` + `operacional.json` | `occurrence.json` | No Desktop, pode virar modelo agregado. |
| `veiculos.json` + `vitimas.json` | `entities.json` | Entidades tipadas. |
| `checklist.json` | `checklist.json` | Ja compativel conceitualmente. |
| `medicoes.json` | `measurements.json` | Renome futuro apenas em major version. |
| `vestigios.json` | `traces.json` | Renome futuro apenas em major version. |
| `fotos.json` | `media_index.json` | Hoje so fotos. Futuro: fotos, videos, audio e anexos. |
| `fotos/` | `media/photos/` | Renome futuro apenas em major version. |
| `timeline.json` | `timeline.json` | Ja compativel. |
| `estatisticas.json` | `stats.json` | Renome futuro apenas em major version. |
| `hashes.json` | `hashes.json` | Manter. |

### `occurrence.json` proposto

Finalidade: agregar identidade, dados administrativos, metadados, localizacao e estado operacional.

Campos obrigatorios propostos:

- `id`;
- `original_mobile_id`;
- `schema_version`;
- `case_type`;
- `status`;
- `created_at`;
- `updated_at`;
- `case_data`;
- `metadata`;

Campos opcionais:

- `started_at`;
- `finished_at`;
- `exported_at`;
- `location`;
- `gps_track_summary`;
- `not_applicable_items`;
- `operational_progress`.

Exemplo minimo:

```json
{
  "id": "occ_123",
  "original_mobile_id": "occ_123",
  "schema_version": "1.0",
  "case_type": "transito",
  "status": "exportada",
  "created_at": "2026-05-25T13:00:00.000",
  "updated_at": "2026-05-25T14:00:00.000",
  "case_data": {
    "bo": "123/2026",
    "municipio": "Macapa",
    "logradouro": "Av. FAB"
  },
  "metadata": {
    "natureza": "colisao",
    "resultado": "vitima_lesionada"
  }
}
```

Observacao de compatibilidade: nao criar este arquivo no mobile agora sem necessidade. O Desktop deve conseguir montar `occurrence.json` internamente a partir dos JSONs atuais.

### `entities.json` proposto

Finalidade: unificar entidades em modelo tipado.

Campos obrigatorios por entidade:

- `id`;
- `type`;
- `label`;
- `source_file`;
- `data`;

Exemplo minimo:

```json
[
  {
    "id": "vehicle_1",
    "type": "vehicle",
    "label": "V1",
    "source_file": "veiculos.json",
    "data": {
      "placa": "ABC1D23",
      "ponto_impacto": "dianteira esquerda"
    }
  }
]
```

### `media_index.json` proposto

Finalidade: catalogo unico de midias.

Campos obrigatorios:

- `id`;
- `type`;
- `relative_path`;
- `sha256`;
- `captured_at`;

Campos opcionais:

- `original_filename`;
- `mime_type`;
- `size_bytes`;
- `source_module`;
- `linked_entities`;
- `metadata_json`.

Exemplo:

```json
[
  {
    "id": "foto_123",
    "type": "photo",
    "relative_path": "media/photos/foto_123.jpg",
    "sha256": "abc...",
    "captured_at": "2026-05-25T13:30:00.000",
    "source_module": "photos",
    "linked_entities": [
      {
        "entity_type": "vehicle",
        "entity_id": "vehicle_1"
      }
    ],
    "metadata_json": {
      "categoria": "veiculo"
    }
  }
]
```

### `traces.json` proposto

Finalidade: vestigios em formato estavel.

Campos obrigatorios:

- `id`;
- `identifier`;
- `type`;
- `description`;

Campos opcionais:

- `location_description`;
- `length`;
- `width`;
- `unit`;
- `direction`;
- `photo_ids`;
- `sketch_element_ids`;
- `notes`;

### `measurements.json` proposto

Finalidade: medicoes de campo.

Campos obrigatorios:

- `id`;
- `label`;
- `value`;
- `unit`;

Campos opcionais:

- `point_a`;
- `point_b`;
- `method`;
- `photo_ids`;
- `sketch_element_ids`;
- `notes`.

### `checklist.json` proposto

Finalidade: checklist final, nao apenas template.

Campos obrigatorios:

- `id`;
- `category`;
- `question`;
- `answer`;
- `required`;
- `origin`.

Campos opcionais:

- `note`;
- `default_note`;
- `linked_media_ids`;
- `deleted_from_template`.

### `timeline.json` proposto

Finalidade: eventos temporais auditaveis.

Campos obrigatorios:

- `id`;
- `type`;
- `occurred_at`;
- `title`;

Campos opcionais:

- `description`;
- `source`;
- `metadata_json`.

### `stats.json` proposto

Finalidade: snapshot de estatisticas no momento da exportacao.

Campos obrigatorios:

- `occurrence_id`;
- `generated_at`;
- `case_type`;
- `status`;
- `duration_seconds`;
- contagens principais.

Observacao: deve ser tratado como dado derivado. O Desktop pode recalcular e comparar.

## 7. Manifest do pacote

Existe hoje como `manifest.json`, mas a proposta abaixo torna o manifest mais explicito para o Desktop 2.0.

Manifest proposto:

```json
{
  "format": "sicroapp",
  "schema_version": "1.0",
  "app_name": "SICRO Operacional",
  "app_version": "1.0.0-alpha+1",
  "export_id": "exp_20260525_143010_abc",
  "occurrence_id": "occ_123",
  "created_at": "2026-05-25T13:00:00.000",
  "exported_at": "2026-05-25T14:30:10.000",
  "device_info": {
    "platform": "android",
    "model": "SM-S928B"
  },
  "operator": {
    "name": "Nome do perito",
    "role": "Perito Criminal",
    "registration": "12345",
    "organization": "Policia Cientifica do Amapa",
    "unit": "..."
  },
  "file_count": 18,
  "media_count": 12,
  "hash_algorithm": "SHA-256",
  "integrity": {
    "hashes_file": "hashes.json",
    "hashes_self_included": false
  },
  "notes": []
}
```

Papel dos campos:

- `format`: identifica o formato, hoje `sicroapp`.
- `schema_version`: versao do contrato de dados.
- `app_name`: nome do app emissor.
- `app_version`: versao do app emissor.
- `export_id`: ID unico da exportacao.
- `occurrence_id`: ID original da ocorrencia no mobile.
- `created_at`: criacao da ocorrencia.
- `exported_at`: momento da exportacao.
- `device_info`: origem tecnica do pacote.
- `operator`: perito configurado no app.
- `file_count`: quantidade de entradas esperadas.
- `media_count`: quantidade de midias esperadas.
- `hash_algorithm`: algoritmo de integridade.
- `integrity`: politica de hash.
- `notes`: avisos gerais.

Necessario para SICRO 2.0:

- manter leitura do manifest atual em portugues;
- mapear `formato` para `format`;
- mapear `versao` para `schema_version`;
- mapear `gerado_em` para `exported_at`;
- mapear `ocorrencia.id` para `occurrence_id`;
- mapear `avisos` para `notes`;
- futuramente adicionar `export_id`, `app_version`, `device_info` e `operator` de forma aditiva.

## 8. Identificadores e chaves

Existe hoje:

- IDs locais gerados por timestamp/microseconds, como `occ_...`, `foto_...`, `vehicle_...`, `victim_...`, `trace_...`, `measurement_...`;
- IDs sao estaveis dentro da ocorrencia;
- fotos sao vinculadas por `photoIds`;
- importacao mobile sempre cria nova ocorrencia com ID `occ_import_<microsecondsSinceEpoch>`;
- IDs originais de fotos sao preservados quando possivel.

Recomendacoes:

- Desktop deve criar um ID proprio para cada ocorrencia importada, preferencialmente UUID v4 ou UUID v7.
- Desktop deve preservar `original_mobile_occurrence_id`.
- Desktop deve criar `import_id` para cada importacao.
- Desktop deve guardar hash SHA-256 do pacote inteiro.
- Desktop nao deve tratar `occ_...` do mobile como chave global.
- Desktop deve namespacear IDs internos do pacote por `import_id`.
- Reimportacao do mesmo pacote deve ser detectada por hash do pacote e/ou `export_id` quando existir.

Tratamento de colisao:

- se `package_sha256` ja existir em `imports`, avisar "pacote ja importado";
- se o mesmo `original_mobile_occurrence_id` aparecer com hash diferente, tratar como nova exportacao da mesma ocorrencia e perguntar se deseja importar como nova versao;
- nunca sobrescrever automaticamente uma ocorrencia Desktop sem confirmacao.

## 9. Midias e evidencias

### Tratamento atual no Operacional

Fotos:

- existem como `FieldPhoto`;
- sao capturadas pela camera;
- sao copiadas para armazenamento privado;
- possuem categoria, data/hora e hash;
- sao exportadas para `fotos/`;
- sao indexadas em `fotos.json`;
- podem ser vinculadas a veiculos, vitimas, vestigios e medicoes por ID.

Videos:

- nao encontrado no codigo atual como captura/exportacao binaria.

Audio:

- nao encontrado no codigo atual como captura/exportacao binaria.

Anexos:

- nao encontrado no codigo atual como modulo generico.

Thumbnails:

- nao encontrado no codigo atual como arquivo persistido/exportado separado.

EXIF:

- nao encontrado no codigo atual como leitura/normalizacao explicita.
- O app copia o arquivo capturado; metadados internos do arquivo podem existir, mas nao ha schema dedicado no JSON.

Geolocalizacao da foto:

- nao encontrado no codigo atual como campo proprio por foto.
- A ocorrencia tem localizacao principal e trilha GPS.

Associacao com entidades:

- existe hoje por listas `fotos` nas entidades.

### Como o Desktop 2.0 deve importar como `evidence_items`

Cada foto deve virar um item de evidencia e um asset de midia.

Campos recomendados:

| Campo | Origem |
| --- | --- |
| `id` | ID novo do Desktop. |
| `original_id` | `fotos.json[].id`. |
| `occurrence_id` | ID interno Desktop. |
| `type` | `photo`. |
| `relative_path` | caminho para copia no workspace `.sicro`. |
| `original_filename` | nome extraido de `fotos.json[].arquivo`. |
| `mime_type` | inferido pela extensao. |
| `size_bytes` | tamanho do arquivo extraido. |
| `sha256` | `hashes.json` ou calculo no Desktop. |
| `captured_at` | `fotos.json[].capturada_em`. |
| `imported_at` | momento de importacao. |
| `source_module` | `photos` ou inferido da categoria. |
| `linked_entity_type` | resolvido a partir dos arrays `fotos` das entidades. |
| `linked_entity_id` | ID interno Desktop da entidade. |
| `metadata_json` | categoria, legenda, arquivo original, hash original e dados brutos. |

Modelo sugerido:

```json
{
  "id": "ev_...",
  "original_id": "foto_123",
  "occurrence_id": "desk_occ_...",
  "type": "photo",
  "relative_path": "media/photos/foto_123.jpg",
  "original_filename": "foto_123.jpg",
  "mime_type": "image/jpeg",
  "size_bytes": 1234567,
  "sha256": "abc...",
  "captured_at": "2026-05-25T13:40:00.000",
  "imported_at": "2026-05-25T15:00:00.000",
  "source_module": "photos",
  "linked_entity_type": "trace",
  "linked_entity_id": "desk_trace_...",
  "metadata_json": {
    "categoria": "vestigio",
    "legenda": "",
    "arquivo_disponivel": true
  }
}
```

## 10. Checklist e dados estruturados

Existe hoje:

- checklist contextual por tipo de pericia;
- checklist base gerado no momento da criacao;
- perguntas editaveis por ocorrencia;
- perguntas adicionaveis e removiveis;
- respostas: `sim`, `nao`, `nao_se_aplica`, `nao_verificado`;
- campo de observacao;
- obrigatoriedade;
- origem `base` ou `adicionado`;
- categorias amplas por tipo de pericia;
- exportacao do checklist final.

Nao encontrado no codigo atual:

- fotos vinculadas diretamente a itens de checklist;
- log de exclusao de item do template;
- template global customizado por perito;
- template institucional remoto.

Como deve virar dado estruturado no Desktop:

- tabela `checklist_items`;
- preservar `original_id`;
- preservar `category`, `question`, `required`, `answer`, `note`, `origin`;
- registrar `schema_version` ou `source_package_version`;
- permitir exibir categorias desconhecidas como texto/codigo.

Regras de importacao:

- se `checklist.json` existir, importar exatamente o checklist final;
- se `checklist.json` estiver ausente em pacote antigo, Desktop pode criar aba vazia com aviso;
- nao tentar reconstruir checklist base no Desktop como se fosse fonte primaria;
- resposta `nao_se_aplica` e resposta do item, diferente de modulo em `operacional.nao_aplicavel`.

## 11. Medicoes e vestigios

### Medicoes atuais

Campos:

- identificador/rotulo;
- ponto A;
- ponto B;
- valor;
- unidade;
- metodo;
- observacao;
- fotos vinculadas;
- vinculos futuros com croqui.

Unidades:

- texto livre no modelo, mas UI usa opcoes como `m`, `cm`, `mm`.

Precisao:

- nao encontrado no codigo atual como campo numerico de incerteza/metrologia.

Localizacao geografica individual:

- nao encontrado no codigo atual para cada medicao.

### Vestigios atuais

Campos:

- identificador;
- tipo;
- descricao;
- localizacao textual;
- comprimento;
- largura;
- unidade;
- direcao;
- observacao;
- fotos vinculadas;
- vinculos futuros com croqui.

Schema de importacao proposto:

```json
{
  "id": "trace_123",
  "original_id": "trace_123",
  "occurrence_id": "desk_occ_...",
  "type": "frenagem",
  "identifier": "E1",
  "description": "Marca de frenagem no sentido bairro-centro",
  "location_description": "Faixa direita",
  "length": 12.5,
  "width": null,
  "unit": "m",
  "direction": "bairro-centro",
  "photo_ids": ["foto_1"],
  "sketch_element_ids": [],
  "metadata_json": {}
}
```

Desktop deve:

- preservar tipos desconhecidos;
- resolver fotos por ID;
- criar registro em `traces`;
- opcionalmente criar `dossie_items` para exibicao;
- manter dados brutos em JSON para compatibilidade futura.

## 12. Localizacao e georreferenciamento

Existe hoje:

- latitude;
- longitude;
- precisao em metros;
- altitude;
- timestamp;
- origem;
- observacao;
- coordenada principal em `localizacao.json`;
- multiplos pontos em `gps_leituras.json`;
- municipio, bairro, logradouro e referencia em `caso.json`;
- distancia aproximada calculada pela trilha em `estatisticas.json`/`operacional.json`.

Nao encontrado no codigo atual:

- coordenadas UTM;
- mapa offline;
- OSM interno no mobile;
- poligono/area;
- geofencing;
- trilha em background com app fechado;
- localizacao individual por foto/vestigio/medicao.

Proposta para Desktop:

- importar `localizacao.json` como `occurrences.primary_latitude`, `primary_longitude`, `accuracy_m`;
- importar `gps_leituras.json` em tabela propria ou JSON bruto;
- permitir abrir OSM/mapa a partir da coordenada principal;
- preservar WGS84 decimal;
- tratar timezone conforme ISO recebido;
- exibir qualidade do GPS:
  - excelente: ate 5 m;
  - aceitavel: ate 15 m;
  - ruim: acima de 15 m.

## 13. Timeline operacional

Existe hoje.

Eventos registrados:

- ocorrencia criada;
- GPS iniciado;
- GPS capturado;
- primeira foto;
- exportacao;
- importacao;
- conclusao;
- reabertura;
- status alterado;
- arquivamento.

Nao encontrado no codigo atual:

- evento especifico de acionamento;
- evento especifico de chegada;
- evento especifico de liberacao do local;
- evento para cada foto individual;
- evento para cada alteracao de checklist;
- audit log completo por campo alterado.

Schema atual:

```json
{
  "id": "timeline_...",
  "tipo": "ocorrencia_criada",
  "titulo": "Ocorrencia criada",
  "descricao": "Dossie operacional criado no aparelho.",
  "ocorrido_em": "2026-05-25T13:00:00.000"
}
```

Schema futuro proposto:

```json
{
  "id": "event_...",
  "type": "photo_captured",
  "occurred_at": "2026-05-25T13:40:00.000",
  "title": "Foto capturada",
  "description": "Primeira foto do dossie",
  "source": "mobile",
  "metadata_json": {
    "photo_id": "foto_123"
  }
}
```

## 14. Compatibilidade e versionamento

Existe hoje:

- `manifest.json.versao = "0.7"`;
- `manifest.json.versoes_compativeis = ["0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7"]`;
- extensao oficial `.sicroapp`;
- extensao legada `.sicrocampo`;
- politica documentada em `docs/SICROAPP_COMPATIBILITY_POLICY.md`;
- regra ja adotada: adicionar campos sem renomear/remover.

Estrategia recomendada:

- mudanca aditiva compativel: incrementar minor (`0.7` -> `0.8`);
- estabilizacao conjunta com Desktop homologado: promover para `1.0`;
- mudanca breaking: incrementar major (`1.x` -> `2.0`);
- manter aliases por pelo menos uma major completa;
- Desktop deve ignorar campos e arquivos desconhecidos;
- Desktop deve preservar copia bruta do pacote original ou seu hash;
- Desktop deve exibir aviso para versao maior desconhecida, mas tentar leitura tolerante quando seguro.

Regras que nao devem ser quebradas:

- nao renomear campo existente;
- nao mudar tipo de campo existente;
- nao mover campo entre JSONs sem manter copia no lugar antigo;
- nao remover `equipe_apoio` enquanto houver possibilidade de Desktop antigo;
- nao transformar `.sicroapp` em formato opaco.

## 15. Validacao e integridade

Validacoes recomendadas para o Desktop 2.0:

1. arquivo existe e possui extensao `.sicroapp` ou `.sicrocampo`;
2. arquivo e ZIP valido;
3. `manifest.json` existe;
4. `manifest.json` e JSON objeto;
5. `formato` e `sicroapp` ou `sicrocampo`;
6. `versao` existe;
7. versao e suportada ou toleravel;
8. arquivos obrigatorios minimos existem;
9. JSONs sao validos;
10. `hashes.json` existe ou gera aviso;
11. hashes conferem para arquivos listados;
12. fotos declaradas existem ou geram aviso;
13. IDs referenciados existem;
14. fotos vinculadas por entidades existem em `fotos.json`;
15. campos obrigatorios minimos existem;
16. pacote ja importado ou nao;
17. tamanho total dentro de limite configurado;
18. nomes de arquivos nao escapam do diretorio de extracao.

Arquivos obrigatorios para importacao minima:

- `manifest.json`;
- `metadados.json`;
- `caso.json`;
- `fotos.json`;
- `observacoes.json`.

Arquivos recomendados:

- `localizacao.json`;
- `hashes.json`;
- `checklist.json`;
- `vestigios.json`;
- `medicoes.json`;
- `timeline.json`;
- `estatisticas.json`;
- `operacional.json`.

Politica de erro:

- ZIP invalido: bloquear;
- manifest ausente/invalido: bloquear;
- hash divergente em JSON critico: bloquear ou exigir confirmacao explicita;
- foto ausente: permitir importacao parcial com alerta;
- modulo ausente: tratar como pacote antigo/nao informado;
- pacote duplicado: avisar e pedir decisao.

## 16. Como o Desktop 2.0 deve importar

Fluxo ideal:

1. Usuario seleciona `.sicroapp`.
2. Comando Rust recebe caminho.
3. Rust valida extensao e ZIP.
4. Rust abre `manifest.json`.
5. Rust valida formato e versao.
6. Rust carrega `hashes.json`.
7. Rust calcula hashes dos arquivos.
8. Rust monta relatorio preliminar de integridade.
9. Rust le JSONs estruturados.
10. Rust cria registro `imports`.
11. Rust cria ou seleciona workspace `.sicro`.
12. Rust cria banco SQLite se necessario.
13. Rust cria ocorrencia interna.
14. Rust copia midias para pasta controlada do workspace.
15. Rust registra `media_assets`.
16. Rust registra `evidence_items`.
17. Rust importa checklist, vestigios, medicoes, entidades, observacoes, timeline e estatisticas.
18. Rust registra `audit_logs`.
19. Frontend React exibe relatorio de importacao.
20. Usuario abre o dossie importado.

Estrutura de workspace sugerida:

```text
caso.sicro/
  sicro.sqlite
  imports/
    <import_id>/
      original_package.sicroapp
      import_report.json
  media/
    photos/
    videos/
    audio/
    attachments/
  exports/
```

## 17. Mapeamento para SQLite do SICRO Desktop 2.0

### `imports`

Campos sugeridos:

- `id` UUID;
- `package_path`;
- `original_filename`;
- `package_sha256`;
- `format`;
- `schema_version`;
- `app_name`;
- `app_version`;
- `mobile_occurrence_id`;
- `imported_at`;
- `status`;
- `warnings_json`;
- `errors_json`;
- `raw_manifest_json`.

### `occurrences`

Campos sugeridos:

- `id` UUID;
- `import_id`;
- `original_mobile_id`;
- `case_type`;
- `case_type_label`;
- `nature`;
- `result`;
- `status`;
- `created_at`;
- `started_at`;
- `finished_at`;
- `duration_seconds`;
- `bo`;
- `requisition`;
- `protocol`;
- `police_unit`;
- `municipality`;
- `district`;
- `street`;
- `reference`;
- `experts`;
- `technical_staff`;
- `police_team`;
- `police_commander`;
- `primary_latitude`;
- `primary_longitude`;
- `primary_accuracy_m`;
- `raw_case_json`;
- `raw_metadata_json`;
- `raw_location_json`.

### `media_assets`

Campos sugeridos:

- `id` UUID;
- `import_id`;
- `occurrence_id`;
- `original_id`;
- `type`;
- `relative_path`;
- `original_package_path`;
- `original_filename`;
- `mime_type`;
- `size_bytes`;
- `sha256`;
- `captured_at`;
- `imported_at`;
- `category`;
- `caption`;
- `raw_json`.

### `evidence_items`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `media_asset_id`;
- `type`;
- `title`;
- `description`;
- `source_module`;
- `linked_entity_type`;
- `linked_entity_id`;
- `captured_at`;
- `metadata_json`.

### `entities`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `original_id`;
- `type`;
- `identifier`;
- `label`;
- `summary`;
- `raw_json`.

Tipos:

- `vehicle`;
- `victim`;
- `body`;
- outros futuros.

### `traces`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `original_id`;
- `identifier`;
- `type`;
- `description`;
- `location_description`;
- `length`;
- `width`;
- `unit`;
- `direction`;
- `note`;
- `raw_json`.

### `measurements`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `original_id`;
- `label`;
- `point_a`;
- `point_b`;
- `value`;
- `unit`;
- `method`;
- `note`;
- `raw_json`.

### `checklist_items`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `original_id`;
- `category`;
- `question`;
- `required`;
- `answer`;
- `note`;
- `default_note`;
- `origin`;
- `raw_json`.

### `dossie_items`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `type`;
- `title`;
- `subtitle`;
- `source_table`;
- `source_id`;
- `sort_order`;
- `metadata_json`.

### `audit_logs`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `import_id`;
- `event_type`;
- `message`;
- `created_at`;
- `metadata_json`.

### `timeline_events`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `original_id`;
- `type`;
- `title`;
- `description`;
- `occurred_at`;
- `raw_json`.

### `occurrence_stats`

Campos sugeridos:

- `id` UUID;
- `occurrence_id`;
- `duration_seconds`;
- `photos_count`;
- `victims_count`;
- `vehicles_count`;
- `traces_count`;
- `measurements_count`;
- `notes_count`;
- `checklist_items_count`;
- `answered_checklist_items_count`;
- `not_applicable_items_count`;
- `best_gps_accuracy_m`;
- `gps_readings_count`;
- `raw_json`.

## 18. Relatorio de importacao

Ao final da importacao, o Desktop deve mostrar:

- pacote importado;
- ocorrencia criada;
- tipo de pericia;
- natureza;
- BO/protocolo;
- municipio/bairro/logradouro;
- quantidade de fotos;
- quantidade de videos: hoje provavelmente 0, pois nao existe no pacote atual;
- quantidade de audios: hoje provavelmente 0;
- checklist importado;
- veiculos importados;
- vitimas/corpos importados;
- vestigios importados;
- medicoes importadas;
- observacoes importadas;
- timeline importada;
- estatisticas importadas;
- hashes verificados;
- arquivos com hash divergente;
- fotos ausentes;
- arquivos ignorados;
- campos desconhecidos preservados/ignorados;
- pacote duplicado ou nao.

Exemplo de resumo:

```text
Importacao concluida com avisos

Ocorrencia: BO 123/2026
Tipo: Transito
Natureza: Colisao
Fotos: 18 importadas, 1 ausente
Checklist: 24 itens
Vestigios: 3
Medicoes: 4
Hashes: 35 verificados
Avisos: 1
```

## 19. Riscos tecnicos

| Risco | Impacto | Mitigacao |
| --- | --- | --- |
| Pacote sem versao | Desktop interpreta errado. | Exigir `manifest.json`; sem versao, modo legado com aviso. |
| IDs locais colidem | Reimportacao ou pacotes diferentes se misturam. | Desktop cria UUID proprio e preserva ID original separado. |
| Fotos sem vinculo | Perda de contexto. | Importar foto mesmo sem vinculo e exibir em galeria geral. |
| Vinculo aponta para foto inexistente | Evidencia incompleta. | Registrar aviso e manter ID bruto no `raw_json`. |
| Arquivos ausentes | Dossie parcial. | Relatorio de importacao e status parcial. |
| Nomes duplicados | Sobrescrita no workspace. | Copiar para nomes controlados por UUID/hash. |
| Hash divergente | Integridade comprometida. | Bloquear ou exigir confirmacao conforme politica. |
| Mudanca futura no Flutter | Desktop quebra silenciosamente. | Politica de compatibilidade, fixtures e testes. |
| Campos livres dificeis de mapear | Dados ficam soltos. | Guardar `raw_json` alem dos campos estruturados. |
| Perda de EXIF | Menos metadados de midia. | Futuramente extrair EXIF no mobile ou Desktop. |
| Timezone/data/hora | Ordem temporal errada. | Exigir ISO-8601; Desktop salva valor original e normalizado. |
| Reimportacao | Duplicidade. | Tabela `imports` com `package_sha256` e `mobile_occurrence_id`. |
| Windows path traversal em ZIP | Risco de seguranca. | Validar caminhos relativos e impedir `..`/absolutos. |
| `.sicrocampo` legado | Pacotes antigos ignorados. | Aceitar extensao e formato legado em modo compativel. |
| Novos tipos de pericia | Desktop sem rotulo. | Exibir codigo desconhecido e preservar dados. |
| Perfil do perito nao exportado | Relatorio Desktop perde operador. | Adicionar `operator` ao manifest de forma aditiva. |
| Audio/video nao binarios | Integracao de Audio e Imagem incompleta. | Criar `media_index` futuro para video/audio/anexos. |

## 20. O que precisa mudar no SICRO Operacional

Recomendacoes aditivas para facilitar o Desktop 2.0:

1. Adicionar `manifest.app_name`.
2. Adicionar `manifest.app_version`.
3. Adicionar `manifest.export_id`.
4. Adicionar `manifest.device_info`.
5. Adicionar `manifest.operator` com perfil do perito.
6. Adicionar `manifest.schema_version` como alias de `versao`, mantendo `versao`.
7. Adicionar `manifest.exported_at` como alias de `gerado_em`, mantendo `gerado_em`.
8. Padronizar chaves JSON em constantes centralizadas no Dart.
9. Adicionar testes fixtures `.sicroapp` por tipo de pericia.
10. Incluir `media_count` e contagens separadas por tipo de midia.
11. Futuramente criar `media_index.json` sem remover `fotos.json`.
12. Futuramente exportar `media/videos`, `media/audio` e `media/attachments` quando esses modulos existirem.
13. Futuramente incluir EXIF/metadados de arquivo quando houver politica tecnica.
14. Adicionar `timezone` ou offset salvo explicitamente, se necessario para padronizacao institucional.
15. Gerar `auditoria.json` quando houver audit log real por alteracao.

O que ja esta adequado:

- `.sicroapp` e ZIP com JSONs e midia;
- existe manifest;
- existe versao;
- existe hash SHA-256 por arquivo;
- caminhos de fotos no pacote sao relativos;
- datas sao ISO-8601;
- IDs sao preservados no pacote;
- campos novos foram adicionados sem remover aliases antigos;
- pacote aceita `.sicrocampo` legado.

## 21. O que NAO deve ser feito

Evitar:

- Desktop depender de classes internas do Flutter;
- Desktop importar `occurrences.json` local do app em vez de `.sicroapp`;
- exportar dados apenas em texto livre;
- usar nome de arquivo como identificador principal;
- armazenar midia em base64 dentro de JSON;
- remover `manifest.json`;
- nao versionar schema;
- nao calcular hashes;
- sobrescrever ocorrencia Desktop em reimportacao sem confirmacao;
- mudar `morte_violenta` para `local_crime` no JSON sem alias/major version;
- remover `equipe_apoio` por causa de `tecnico_pericial`;
- renomear `vestigios.json` para `traces.json` sem major version;
- renomear `fotos.json` para `media_index.json` sem manter o arquivo antigo;
- transformar `.sicroapp` em formato opaco proprietario sem manifest;
- depender de ordem dos arquivos dentro do ZIP;
- assumir que todo pacote tera vitimas, veiculos, medicoes ou vestigios;
- tratar ausencia de dado e `nao_aplicavel` como a mesma coisa.

## 22. Checklist para o futuro Spike de Importacao

### Spike E - Importacao `.sicroapp`

O spike sera aprovado se o Desktop conseguir:

- selecionar um arquivo `.sicroapp`;
- aceitar tambem `.sicrocampo` em modo legado;
- validar se e ZIP;
- ler `manifest.json`;
- validar `formato`/`versao`;
- ler `hashes.json`;
- calcular e validar hashes;
- mostrar avisos de integridade;
- criar workspace `.sicro`;
- criar banco SQLite;
- criar registro em `imports`;
- criar ocorrencia em `occurrences`;
- importar `caso.json`;
- importar `metadados.json`;
- importar `localizacao.json`;
- importar `fotos.json`;
- copiar fotos para o workspace;
- registrar `media_assets`;
- registrar `evidence_items`;
- importar `checklist.json`;
- importar `veiculos.json`;
- importar `vitimas.json`;
- importar `vestigios.json`;
- importar `medicoes.json`;
- importar `observacoes.json`;
- importar `timeline.json`;
- importar `estatisticas.json`;
- importar `operacional.json`;
- resolver vinculos de fotos por ID;
- registrar `audit_logs`;
- mostrar relatorio de importacao;
- reabrir a ocorrencia importada;
- exibir dossie em abas basicas.

Fixtures recomendadas:

```text
tests/fixtures/sicroapp/
  transito_colisao_v0.7.sicroapp
  transito_sem_vitima_v0.7.sicroapp
  transito_carro_oficial_v0.7.sicroapp
  local_crime_homicidio_v0.7.sicroapp
  patrimonio_arrombamento_v0.7.sicroapp
  ambiental_desmatamento_v0.7.sicroapp
  balistica_confronto_v0.7.sicroapp
  audio_imagem_cftv_v0.7.sicroapp
  papiloscopia_local_v0.7.sicroapp
```

## 23. Entrega final

### Resumo executivo

O SICRO Operacional ja possui um formato `.sicroapp` real, estruturado, versionado e importavel pelo proprio app mobile. O pacote e um ZIP renomeado, com JSONs separados por modulo, fotos em pasta propria, manifest e hashes SHA-256. O Desktop 2.0 nao deve depender do codigo Flutter; deve importar o pacote como contrato de dados.

A importacao minima no Desktop deve ler manifest, metadados, caso, localizacao, fotos e observacoes. A importacao completa deve incluir checklist, entidades, vestigios, medicoes, GPS, timeline, estatisticas e estado operacional.

O maior cuidado e compatibilidade: manter a regra "so adicionar; nunca renomear, mover, remover ou mudar tipo". A nomenclatura visual pode evoluir, mas codigos contratuais precisam ser preservados.

### Schema proposto do `.sicroapp`

Curto prazo: Desktop deve suportar a estrutura atual `0.7`:

```text
manifest.json
metadados.json
caso.json
localizacao.json
gps_leituras.json
estatisticas.json
timeline.json
checklist.json
fotos.json
veiculos.json
vitimas.json
vestigios.json
medicoes.json
observacoes.json
operacional.json
hashes.json
fotos/
```

Futuro major version sincronizado:

```text
manifest.json
occurrence.json
entities.json
checklist.json
measurements.json
traces.json
media_index.json
timeline.json
stats.json
hashes.json
media/
```

### Arquivos do app que precisarao atencao em ajustes futuros

- `lib/core/data/sicrocampo_package_contract.dart`;
- `lib/core/data/sicrocampo_export_service.dart`;
- `lib/core/data/sicroapp_import_service.dart`;
- `lib/domain/models/occurrence.dart`;
- `lib/domain/models/forensic_case_metadata.dart`;
- `lib/domain/models/case_data.dart`;
- `lib/domain/models/field_photo.dart`;
- `lib/domain/models/trace_record.dart`;
- `lib/domain/models/measurement_record.dart`;
- `lib/domain/models/checklist_item.dart`;
- `lib/domain/models/app_settings.dart`;
- `docs/SICROAPP_FORMAT_SPEC.md`;
- `docs/SICROAPP_COMPATIBILITY_POLICY.md`.

### Decisoes pendentes

- O Desktop 2.0 vai aceitar importacao parcial quando hash de foto divergir?
- O Desktop 2.0 vai armazenar copia integral do pacote original no workspace?
- O Desktop 2.0 vai tratar reimportacao como nova versao da mesma ocorrencia ou nova ocorrencia?
- O formato `1.0` sera liberado antes ou depois do primeiro importador Desktop homologado?
- O perfil global do perito entrara no manifest como `operator` ja no proximo minor?
- Audio/video/anexos serao adicionados como novo `media_index.json` ou ficarao para major version?
- O codigo contratual `morte_violenta` sera mantido permanentemente, com rotulo "Local de crime", ou havera migracao major futura?

### Recomendacao clara do proximo passo

O proximo passo recomendado e o **Spike E - Leitor tecnico `.sicroapp` no Desktop 2.0**:

1. implementar em Rust somente abertura ZIP + leitura de manifest;
2. validar hashes;
3. listar arquivos e contagens;
4. extrair fotos para pasta controlada;
5. criar SQLite minimo com `imports`, `occurrences`, `media_assets` e `evidence_items`;
6. abrir uma tela React simples com relatorio de importacao.

Depois disso, evoluir para importacao completa de checklist, entidades, vestigios, medicoes, timeline e estatisticas.
