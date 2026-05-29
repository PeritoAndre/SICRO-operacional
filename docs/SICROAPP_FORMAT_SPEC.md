# SICROAPP Format Spec

Especificacao tecnica do pacote `.sicroapp` gerado pelo SICRO Operacional.

Status desta auditoria: formato atual do app em `24/05/2026`.
Versao do pacote: `0.7`.
Extensao oficial atual: `.sicroapp`.
Extensao legada aceita para compatibilidade futura: `.sicrocampo`.

Esta documentacao descreve o contrato de dados para orientar a futura
importacao no SICRO Desktop. Ela nao implementa o importador desktop.

## 1. Visao Geral

O arquivo `.sicroapp` e um arquivo ZIP renomeado. O conteudo e composto por
JSONs em UTF-8, fotos binarizadas na pasta `fotos/` e um arquivo de hashes
SHA-256 para verificacao de integridade.

O nome interno de algumas classes no codigo ainda usa `SicroCampo` por heranca
historica do projeto, mas o formato exportado atual e `sicroapp`.

Regras gerais:

- Datas sao gravadas como `String` ISO-8601.
- Campos textuais vazios normalmente sao gravados como `""`.
- Campos numericos ausentes normalmente aparecem como `null`.
- Listas vazias sao gravadas como `[]`.
- Caminhos de fotos dentro do pacote sao relativos ao ZIP.
- IDs sao referencias internas do dossie e devem ser preservados durante a
  importacao.
- O Desktop deve tratar campos desconhecidos como extensoes futuras e ignora-los
  com seguranca.

## 2. Estrutura Completa Do Pacote

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

Arquivos reservados no contrato, mas ainda nao gerados pela exportacao atual:

```text
croqui_rapido.json
auditoria.json
```

Relatorios PDF de plantao e relatorios estatisticos sao gerados como arquivos
separados e nao entram no `.sicroapp` atual.

## 3. Inventario De Arquivos

| Caminho | Tipo | Gerado hoje | Finalidade |
| --- | --- | --- | --- |
| `manifest.json` | objeto | Sim | Cabecalho do pacote, versao, contagens, lista de arquivos e avisos. |
| `metadados.json` | objeto | Sim | Tipo de pericia, natureza, resultado e metadados especificos. |
| `caso.json` | objeto | Sim | Dados administrativos e de local da ocorrencia. |
| `localizacao.json` | objeto | Sim | Coordenada principal salva no dossie. |
| `gps_leituras.json` | lista | Sim | Leituras GPS continuas registradas durante a sessao. |
| `estatisticas.json` | objeto | Sim | Estatisticas operacionais derivadas da ocorrencia. |
| `timeline.json` | lista | Sim | Eventos automaticos da ocorrencia. |
| `checklist.json` | lista | Sim | Checklist final da ocorrencia, incluindo itens editados/adicionados. |
| `fotos.json` | lista | Sim | Metadados das fotos e ponteiro para o arquivo no ZIP. |
| `veiculos.json` | lista | Sim | Veiculos registrados e vinculos de fotos. |
| `vitimas.json` | lista | Sim | Vitimas/corpos registrados e vinculos de fotos. |
| `vestigios.json` | lista | Sim | Vestigios registrados, vinculos de fotos e futuros vinculos com croqui. |
| `medicoes.json` | lista | Sim | Medicoes registradas, vinculos de fotos e futuros vinculos com croqui. |
| `observacoes.json` | lista | Sim | Notas livres de campo. |
| `operacional.json` | objeto | Sim | Progresso operacional, modulos, nao aplicaveis e sessao. |
| `hashes.json` | objeto | Sim | Hash SHA-256 dos arquivos do pacote, exceto o proprio `hashes.json`. |
| `fotos/` | pasta | Sim | Fotos binarizadas incluidas no pacote. |

## 4. Convencoes De Campos

Na coluna "Obrigatorio":

- `Sim`: o campo e gravado pelo app atual e deve ser esperado pelo Desktop.
- `Opcional`: pode vir vazio, nulo, ausente em pacote antigo ou sem dado de
  campo.
- `Condicional`: existe ou tem significado conforme tipo de pericia/modulo.

O importador desktop deve validar rigidamente `manifest.json`, mas ser tolerante
com JSONs de modulo vazios.

## 5. `manifest.json`

Finalidade: identificar o pacote, versao, resumo da ocorrencia, contagens e
arquivos esperados.

Exemplo:

```json
{
  "formato": "sicroapp",
  "formatos_compativeis": ["sicroapp", "sicrocampo"],
  "extensoes_compativeis": [".sicroapp", ".sicrocampo"],
  "versao": "0.7",
  "versoes_compativeis": ["0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7"],
  "gerado_em": "2026-05-22T14:30:10.000",
  "ocorrencia": {
    "id": "occ_123",
    "status": "exportada",
    "status_operacional": "exportada",
    "iniciado_em": "2026-05-22T13:10:00.000",
    "concluido_em": "2026-05-22T14:20:00.000",
    "duracao_segundos": 4200,
    "tipo_pericia": "transito",
    "natureza": "colisao",
    "resultado": "vitima_lesionada",
    "criado_em": "2026-05-22T13:05:00.000",
    "atualizado_em": "2026-05-22T14:29:00.000"
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

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `formato` | string | Sim | Valor atual: `sicroapp`. Legado aceito: `sicrocampo`. |
| `formatos_compativeis` | lista de string | Sim | Hoje: `sicroapp`, `sicrocampo`. |
| `extensoes_compativeis` | lista de string | Sim | Hoje: `.sicroapp`, `.sicrocampo`. |
| `versao` | string | Sim | Versao atual do contrato: `0.7`. |
| `versoes_compativeis` | lista de string | Opcional | Versoes da mesma familia lidas em modo compativel. Hoje: `0.1`, `0.2`, `0.3`, `0.4`, `0.5`, `0.6`, `0.7`. |
| `gerado_em` | string ISO-8601 | Sim | Data/hora da exportacao. |
| `ocorrencia` | objeto | Sim | Resumo operacional da ocorrencia. |
| `contagens` | objeto | Sim | Quantidades dos modulos exportados. |
| `arquivos` | lista de string | Sim | Arquivos esperados dentro do ZIP. |
| `avisos` | lista de string | Sim | Avisos de exportacao, por exemplo foto ausente. |

Campos de `ocorrencia`:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno da ocorrencia no app. |
| `status` | string | Sim | `em_andamento`, `concluida`, `exportada`, `pendente_revisao`, `incompleta`, `arquivada`. |
| `status_operacional` | string | Sim | Mesmo dominio operacional do status. |
| `iniciado_em` | string ISO-8601 | Sim | Usa `startedAt`; se ausente, usa criacao. |
| `concluido_em` | string ISO-8601 ou null | Opcional | Preenchido quando a pericia foi concluida. |
| `duracao_segundos` | inteiro | Sim | Duracao calculada. |
| `tipo_pericia` | string | Sim | `transito`, `morte_violenta`, `patrimonio`, `ambiental`, `balistica_forense`, `audio_imagem`, `papiloscopia`. |
| `natureza` | string ou null | Opcional | Codigo conforme tipo de pericia. |
| `resultado` | string | Sim | Resultado transversal. |
| `criado_em` | string ISO-8601 | Sim | Data de criacao. |
| `atualizado_em` | string ISO-8601 | Sim | Ultima atualizacao local antes da exportacao. |

Nota de compatibilidade: a interface exibe `Local de crime`, mas o valor
contratual continua sendo `morte_violenta` para preservar leitura de pacotes
antigos e sincronizacao com o SICRO Desktop.

## 6. `metadados.json`

Finalidade: definir o tipo da pericia e seus metadados contextuais.

Exemplo transito:

```json
{
  "tipo_pericia": "transito",
  "natureza": "colisao",
  "envolvidos": ["carro", "moto"],
  "veiculo_oficial": true,
  "resultado": "vitima_lesionada",
  "resumo": "Transito - Colisao - Carro x Moto - Carro oficial - Com vitima lesionada"
}
```

Exemplo local de crime:

```json
{
  "tipo_pericia": "morte_violenta",
  "natureza": "homicidio",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Local de crime - Homicidio - Corpo presente no local - 1 vitima - Via publica",
  "morte_violenta": {
    "natureza": "homicidio",
    "estado_vitima_corpo": "corpo_presente",
    "quantidade_vitimas": "uma_vitima",
    "ambiente_local": "via_publica",
    "vestigios_esperados": ["sangue_mancha_biologica", "capsulas_estojos"]
  }
}
```

Exemplo patrimonio:

```json
{
  "tipo_pericia": "patrimonio",
  "natureza": "arrombamento",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Patrimonio - Arrombamento",
  "patrimonio": {
    "natureza": "arrombamento"
  }
}
```

Exemplo ambiental:

```json
{
  "tipo_pericia": "ambiental",
  "natureza": "poluicao_hidrica",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Pericia ambiental - Poluicao hidrica - Corpo hidrico",
  "ambiental": {
    "natureza": "poluicao_hidrica",
    "contexto_local": "corpo_hidrico",
    "vestigios_esperados": [
      "corpo_hidrico_atingido",
      "efluente_contaminante",
      "amostras"
    ]
  }
}
```

Exemplo balistica forense:

```json
{
  "tipo_pericia": "balistica_forense",
  "natureza": "confronto_balistico",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Balistica Forense - Confronto balistico - Material apreendido",
  "balistica_forense": {
    "natureza": "confronto_balistico",
    "contexto": "material_apreendido",
    "vestigios_esperados": [
      "arma_fogo",
      "capsulas_estojos",
      "projeteis",
      "padroes_balisticos",
      "embalagens_lacres",
      "documentos_requisicao"
    ]
  }
}
```

Exemplo audio e imagem:

```json
{
  "tipo_pericia": "audio_imagem",
  "natureza": "preservacao_cftv",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Audio e Imagem - Preservacao/coleta de CFTV - Sistema CFTV",
  "audio_imagem": {
    "natureza": "preservacao_cftv",
    "contexto": "sistema_cftv",
    "vestigios_esperados": [
      "dvr_nvr_cftv",
      "sistema_camera",
      "dispositivo_armazenamento",
      "videos",
      "credenciais_acesso",
      "hashes"
    ]
  }
}
```

Exemplo papiloscopia:

```json
{
  "tipo_pericia": "papiloscopia",
  "natureza": "levantamento_local",
  "envolvidos": [],
  "resultado": "nao_informado",
  "resumo": "Papiloscopia - Levantamento em local de crime - Local de crime",
  "papiloscopia": {
    "natureza": "levantamento_local",
    "contexto": "local_crime",
    "vestigios_esperados": [
      "impressao_latente",
      "impressao_patente",
      "impressao_moldada",
      "objetos_questionados",
      "suportes_adesivos",
      "fotografias"
    ]
  }
}
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `tipo_pericia` | string | Sim | `transito`, `morte_violenta`, `patrimonio`, `ambiental`, `balistica_forense`, `audio_imagem`, `papiloscopia`. |
| `natureza` | string ou null | Opcional | Natureza principal conforme tipo. |
| `envolvidos` | lista de string | Sim | Usado principalmente em transito. |
| `veiculo_oficial` | booleano | Sim | Campo aditivo de transito. Indica atendimento envolvendo carro/veiculo oficial, inclusive quando nao ha vitima. |
| `resultado` | string | Sim | Resultado transversal. |
| `resumo` | string | Sim | Texto gerado para exibicao. |
| `morte_violenta` | objeto | Condicional | Presente quando `tipo_pericia = morte_violenta`. |
| `patrimonio` | objeto | Condicional | Presente quando `tipo_pericia = patrimonio`. |
| `ambiental` | objeto | Condicional | Presente quando `tipo_pericia = ambiental`. |
| `balistica_forense` | objeto | Condicional | Presente quando `tipo_pericia = balistica_forense`. |
| `audio_imagem` | objeto | Condicional | Presente quando `tipo_pericia = audio_imagem`. |
| `papiloscopia` | objeto | Condicional | Presente quando `tipo_pericia = papiloscopia`. |

Catalogos:

- `tipo_pericia`: `transito`, `morte_violenta`, `patrimonio`, `ambiental`,
  `balistica_forense`, `audio_imagem`, `papiloscopia`.
- Naturezas de transito: `colisao`, `capotamento`, `tombamento`,
  `saida_pista`, `choque_objeto_fixo`, `incendio_veicular`,
  `derramamento_carga`, `outro`.
- Envolvidos de transito: `carro`, `moto`, `bicicleta`, `caminhao`, `onibus`,
  `pedestre`, `objeto_fixo`, `animal`, `outro`.
- Resultado: `sem_vitima`, `vitima_lesionada`, `vitima_fatal`,
  `multiplas_vitimas`, `nao_informado`.
- Naturezas de local de crime: `homicidio`, `suicidio`, `morte_suspeita`,
  `cadaver_encontrado`, `ossada_restos_humanos`, `intervencao_policial`,
  `encontro_cadaver`, `local_vestigio_biologico`, `outro`.
- Estado da vitima/corpo: `corpo_presente`, `corpo_removido`,
  `corpo_parcialmente_presente`, `apenas_vestigios_biologicos`,
  `nao_informado`.
- Quantidade de vitimas: `uma_vitima`, `duas_vitimas`, `tres_ou_mais`,
  `nao_informado`.
- Ambiente local: `residencia`, `via_publica`, `area_mata`,
  `area_rural_ramal`, `estabelecimento_comercial`,
  `ambiente_institucional`, `veiculo`, `outro`.
- Vestigios esperados em local de crime: `sangue_mancha_biologica`,
  `capsulas_estojos`, `projeteis`, `arma_branca`, `arma_fogo`,
  `sinais_luta`, `arrastamento`, `pegadas`, `objetos_deslocados`,
  `vestes_pertences`, `outro`.
- Naturezas de patrimonio: `avaliacao_direta`, `avaliacao_indireta`,
  `danos`, `arrombamento`, `incendio`.
- Naturezas ambientais: `desmatamento`, `maus_tratos_animais`,
  `poluicao_hidrica`, `incendio_florestal`, `necropsia_veterinaria`, `outro`.
- Contexto ambiental: `area_rural`, `area_urbana`, `area_mata`,
  `corpo_hidrico`, `area_protegida`, `empreendimento`,
  `ambiente_veterinario`, `outro`.
- Vestigios esperados ambientais: `supressao_vegetal`,
  `area_protegida_atingida`, `corpo_hidrico_atingido`,
  `efluente_contaminante`, `condicao_animal`, `cadaver_animal`,
  `material_biologico`, `indicadores_queima`, `amostras`,
  `documentos_licencas`, `outro`.
- Naturezas de balistica forense: `confronto_balistico`,
  `coleta_gsr_mev_eds`, `eficiencia_arma_fogo`, `eficiencia_cartuchos`,
  `outro`.
- Contexto de balistica forense: `laboratorio`, `local_crime`, `veiculo`,
  `pessoa_suspeita`, `cadaver`, `material_apreendido`, `outro`.
- Vestigios esperados em balistica forense: `arma_fogo`,
  `municao_cartuchos`, `capsulas_estojos`, `projeteis`,
  `padroes_balisticos`, `residuo_tiro_gsr`, `vestes`,
  `superficie_veiculo_local`, `embalagens_lacres`,
  `documentos_requisicao`, `outro`.
- Naturezas de audio e imagem: `analise_conteudo_imagem`,
  `melhoramento_imagem`, `reconhecimento_imagem`, `comparacao_facial`,
  `verificacao_edicao_imagem`, `comparacao_locutor`, `preservacao_cftv`,
  `estimativa_estatura`, `outro`.
- Contexto de audio e imagem: `laboratorio`, `local_crime`, `sistema_cftv`,
  `midia_digital`, `dispositivo_movel`, `conteudo_internet`,
  `padrao_pessoa`, `outro`.
- Vestigios esperados em audio e imagem: `midia_original`,
  `arquivos_multimidia`, `imagens`, `videos`, `audios`, `dvr_nvr_cftv`,
  `dispositivo_armazenamento`, `metadados`, `hashes`, `material_padrao`,
  `padrao_vocal`, `imagens_faciais`, `quadros_frames`,
  `credenciais_acesso`, `sistema_camera`, `outro`.
- Naturezas de papiloscopia: `identificacao_criminal`,
  `levantamento_local`, `levantamento_laboratorio`,
  `identificacao_necropapiloscopica`, `outro`.
- Contexto de papiloscopia: `pessoa_viva`, `local_crime`, `laboratorio`,
  `cadaver`, `objeto_suporte`, `documento`, `outro`.
- Vestigios esperados em papiloscopia: `impressoes_digitais`,
  `impressoes_palmares`, `impressao_latente`, `impressao_patente`,
  `impressao_moldada`, `captura_biometrica`, `objetos_questionados`,
  `suportes_adesivos`, `fotografias`, `afis_abis`,
  `material_necropapiloscopico`, `reagentes_quimicos`, `outro`.

## 7. `caso.json`

Finalidade: dados administrativos da ocorrencia e dados do local.

Exemplo:

```json
{
  "bo": "123/2026",
  "requisicao": "REQ-45",
  "protocolo": "PROTO-2026-001",
  "delegacia": "Delegacia X",
  "municipio": "Macapa",
  "bairro": "Centro",
  "logradouro": "Av. FAB",
  "referencia": "Proximo ao cruzamento",
  "peritos": "Perito A; Perito B",
  "tecnico_pericial": "Tecnico A",
  "equipe_apoio": "Tecnico A",
  "equipe_policial": "2o BPM",
  "comandante_policial": "Tenente Fulano",
  "acionamento_em": "2026-05-22T13:00:00.000",
  "chegada_em": "2026-05-22T13:25:00.000",
  "encerramento_em": null
}
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `bo` | string | Opcional | Numero do BO. |
| `requisicao` | string | Opcional | Requisicao/oficio. |
| `protocolo` | string | Opcional | Protocolo local. |
| `delegacia` | string | Opcional | Unidade demandante. |
| `municipio` | string | Opcional | Municipio. |
| `bairro` | string | Opcional | Bairro. |
| `logradouro` | string | Opcional | Endereco/logradouro. |
| `referencia` | string | Opcional | Ponto de referencia. |
| `peritos` | string | Opcional | Peritos da ocorrencia. |
| `tecnico_pericial` | string | Opcional | Tecnico pericial/equipe tecnica de apoio. |
| `equipe_apoio` | string | Opcional | Alias legado de `tecnico_pericial`, mantido por compatibilidade. |
| `equipe_policial` | string | Opcional | Equipe policial/batalhao responsavel pela preservacao inicial. |
| `comandante_policial` | string | Opcional | Comandante ou responsavel policial no local. |
| `acionamento_em` | string ISO-8601 ou null | Opcional | Horario de acionamento. |
| `chegada_em` | string ISO-8601 ou null | Opcional | Horario de chegada. |
| `encerramento_em` | string ISO-8601 ou null | Opcional | Horario de encerramento informado. |

Observacao: o perfil global do perito salvo no app (`nome`, `cargo`,
`matricula`, `orgao`, `unidade`) ainda nao e exportado no `.sicroapp`. O campo
mais proximo hoje e `caso.json.peritos`.

## 8. `localizacao.json`

Finalidade: coordenada principal da ocorrencia. Pode ser a leitura manual salva
ou a melhor leitura automatica usada pelo app.

Exemplo:

```json
{
  "latitude": 0.0656487,
  "longitude": -51.0521516,
  "precisao_m": 4.3,
  "altitude_m": 18.0,
  "capturado_em": "2026-05-22T13:30:00.000",
  "origem": "gps",
  "observacao": ""
}
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `latitude` | numero ou null | Opcional | Latitude decimal WGS84. |
| `longitude` | numero ou null | Opcional | Longitude decimal WGS84. |
| `precisao_m` | numero ou null | Opcional | Precisao horizontal em metros. |
| `altitude_m` | numero ou null | Opcional | Altitude em metros, se disponivel. |
| `capturado_em` | string ISO-8601 ou null | Opcional | Data/hora da leitura. |
| `origem` | string | Sim | Hoje normalmente `gps`. |
| `observacao` | string | Opcional | Observacao livre. |

## 9. `gps_leituras.json`

Finalidade: historico de leituras GPS registradas durante a sessao operacional.

Formato: lista de objetos com a mesma estrutura de `localizacao.json`.

Exemplo:

```json
[
  {
    "latitude": 0.0656503,
    "longitude": -51.0521512,
    "precisao_m": 9.5,
    "altitude_m": null,
    "capturado_em": "2026-05-22T13:29:10.000",
    "origem": "gps",
    "observacao": ""
  }
]
```

Pode ser `[]` quando nao houve monitoramento ou leitura persistida.

## 10. `fotos.json` E Pasta `fotos/`

Finalidade: indexar fotos capturadas no app e apontar para os binarios dentro do
ZIP.

Exemplo:

```json
[
  {
    "id": "foto_001",
    "arquivo": "fotos/foto_001.jpg",
    "categoria": "visao_geral",
    "capturada_em": "2026-05-22T13:40:00.000",
    "legenda": "",
    "sha256": "a3f0...",
    "sha256_original": "a3f0...",
    "entidade_vinculada": null,
    "arquivo_disponivel": true
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID da foto. Deve ser preservado para vinculos. |
| `arquivo` | string | Sim | Caminho relativo no pacote, por exemplo `fotos/foto_001.jpg`. |
| `categoria` | string | Sim | Categoria da foto. |
| `capturada_em` | string ISO-8601 | Sim | Data/hora da captura. |
| `legenda` | string | Opcional | Legenda/descricao. |
| `sha256` | string | Opcional | Hash do arquivo empacotado, quando disponivel. |
| `sha256_original` | string | Opcional | Hash salvo originalmente no app. |
| `entidade_vinculada` | string ou null | Opcional | Vinculo legado/simples. Preferir vinculos nas entidades. |
| `arquivo_disponivel` | booleano | Sim | `false` se a foto constava no dossie mas o arquivo local nao foi encontrado. |

Categorias de foto:

`visao_geral`, `aproximacao`, `detalhe`, `veiculo`, `vitima`, `vestigio`,
`sinalizacao`, `frenagem`, `semaforo`, `dano`, `documento`, `outros`.

Regra de vinculos:

- O Desktop deve tratar `fotos.json` como catalogo de midia.
- Entidades usam listas `fotos` contendo IDs de fotos.
- Nao duplicar binarios quando uma foto estiver vinculada a mais de uma
  entidade.

## 11. `checklist.json`

Finalidade: checklist final da ocorrencia, incluindo perguntas base,
perguntas adicionadas, edicoes locais, respostas e observacoes.

Exemplo:

```json
[
  {
    "id": "transito_preservacao_001",
    "categoria": "preservacao",
    "pergunta": "Local isolado?",
    "obrigatorio": true,
    "resposta": "sim",
    "observacao": "Isolamento realizado pela PM.",
    "observacao_padrao": "",
    "origem": "base"
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID do item. |
| `categoria` | string | Sim | Secao/categoria operacional. |
| `pergunta` | string | Sim | Texto da pergunta. |
| `obrigatorio` | booleano | Sim | Indica item obrigatorio. |
| `resposta` | string | Sim | `nao_verificado`, `sim`, `nao`, `nao_se_aplica`. |
| `observacao` | string | Opcional | Observacao do perito. |
| `observacao_padrao` | string | Opcional | Campo reservado para texto orientativo. |
| `origem` | string | Sim | `base` ou `adicionado`. |

Categorias:

`preservacao`, `vitimas`, `veiculos`, `condicoes_via`, `pavimento`,
`iluminacao`, `clima_visibilidade`, `sinalizacao`, `semaforo`, `vestigios`,
`corpo_vitima`, `vestigios_biologicos`, `vestigios_balisticos`,
`armas_objetos`, `ambiente`, `registro_fotografico`, `bens_avaliacao`,
`documentacao`, `danos`, `arrombamento`, `incendio`,
`planejamento_ambiental`, `local_ambiental`, `dano_ambiental`,
`amostras_coleta`, `cadeia_custodia`, `recebimento_balistico`,
`seguranca_balistica`, `armas_fogo`, `municoes`, `coleta_gsr`,
`confronto_balistico`, `recebimento_multimidia`, `preservacao_multimidia`,
`adequabilidade_multimidia`, `processamento_multimidia`, `coleta_cftv`,
`comparacao_facial`, `comparacao_locutor`, `autenticidade_imagem`,
`biosseguranca_papiloscopia`, `coleta_papiloscopica`,
`revelacao_papiloscopica`, `identificacao_papiloscopica`,
`laboratorio_papiloscopia`, `necropapiloscopia`.

## 12. `veiculos.json`

Finalidade: veiculos registrados na ocorrencia.

Exemplo:

```json
[
  {
    "id": "veh_001",
    "identificador": "V1",
    "placa": "ABC1D23",
    "tipo": "Carro",
    "modelo": "Sedan",
    "cor": "Prata",
    "sentido_trafego": "Centro-bairro",
    "posicao_final": "Faixa direita",
    "ponto_impacto": "Regiao frontal direita",
    "avarias": "Danos frontais",
    "condutor": "Nao informado",
    "proprietario": "",
    "observacao": "",
    "fotos": ["foto_010", "foto_011"]
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno do veiculo. |
| `identificador` | string | Sim | Exemplo: `V1`, `V2`. |
| `placa` | string | Opcional | Placa. |
| `tipo` | string | Opcional | Tipo livre. |
| `modelo` | string | Opcional | Modelo livre. |
| `cor` | string | Opcional | Cor. |
| `sentido_trafego` | string | Opcional | Sentido declarado. |
| `posicao_final` | string | Opcional | Posicao final resumida. |
| `ponto_impacto` | string | Opcional | Ponto/regiao de impacto no veiculo. |
| `avarias` | string | Opcional | Danos/avarias. |
| `condutor` | string | Opcional | Condutor. |
| `proprietario` | string | Opcional | Proprietario. |
| `observacao` | string | Opcional | Observacao livre. |
| `fotos` | lista de string | Sim | IDs de fotos vinculadas. |

## 13. `vitimas.json`

Finalidade: vitimas/corpos registrados. Em local de crime, o modulo e
interpretado como "Vitimas/Corpos".

Exemplo:

```json
[
  {
    "id": "vit_001",
    "identificador": "P1",
    "nome": "Nao identificado",
    "condicao": "obito",
    "tipo": "pedestre",
    "removida": "nao",
    "socorrida_por": "",
    "destino": "",
    "removida_em": null,
    "posicao_corporal": "Decubito dorsal",
    "epi": "",
    "observacao": "",
    "fotos": ["foto_020"]
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno. |
| `identificador` | string | Sim | Exemplo: `P1`, `P2`. |
| `nome` | string | Opcional | Nome, se conhecido. |
| `condicao` | string | Sim | `ilesa`, `lesionada`, `obito`, `desconhecida`. |
| `tipo` | string | Sim | `condutor`, `passageiro`, `pedestre`, `ciclista`, `motociclista`, `outro`. |
| `removida` | string | Sim | `sim`, `nao`, `nao_informado`. |
| `socorrida_por` | string | Opcional | Equipe/servico. |
| `destino` | string | Opcional | Hospital/destino. |
| `removida_em` | string ISO-8601 ou null | Opcional | Horario aproximado. |
| `posicao_corporal` | string | Opcional | Descricao livre. |
| `epi` | string | Opcional | Uso de capacete/EPI ou vestimentas relevantes. |
| `observacao` | string | Opcional | Observacao livre. |
| `fotos` | lista de string | Sim | IDs de fotos vinculadas. |

## 14. `vestigios.json`

Finalidade: vestigios tecnicos observados na ocorrencia.

Exemplo:

```json
[
  {
    "id": "vest_001",
    "identificador": "E1",
    "tipo": "frenagem",
    "descricao": "Marca de frenagem na faixa direita",
    "comprimento": 12.4,
    "largura": null,
    "unidade": "m",
    "direcao": "Norte-Sul",
    "localizacao_textual": "Antes do ponto de impacto",
    "observacao": "",
    "fotos": ["foto_030"],
    "croqui": []
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno. |
| `identificador` | string | Sim | Exemplo: `E1`, `E2`. |
| `tipo` | string | Sim | Tipo do vestigio. |
| `descricao` | string | Opcional | Descricao livre. |
| `comprimento` | numero ou null | Opcional | Comprimento aproximado. |
| `largura` | numero ou null | Opcional | Largura aproximada. |
| `unidade` | string | Sim | Geralmente `m`; pode ser `cm`, `mm` etc. |
| `direcao` | string | Opcional | Direcao/sentido. |
| `localizacao_textual` | string | Opcional | Posicao resumida. |
| `observacao` | string | Opcional | Observacao livre. |
| `fotos` | lista de string | Sim | IDs de fotos vinculadas. |
| `croqui` | lista de string | Sim | Reservado para IDs de elementos do croqui. |

Tipos de vestigio:

`frenagem`, `derrapagem`, `arrasto`, `fragmento`, `mancha`, `sulco`, `pneu`,
`fluido`, `peca_desprendida`, `marca_impacto`, `sangue`,
`vestigio_biologico`, `capsula_estojo`, `projetil`, `perfuracao`,
`arma_branca`, `arma_fogo`, `sinal_luta`, `pegada`, `objeto_deslocado`,
`dano`, `marca_ferramenta`, `rompimento`, `fechadura`, `porta_janela`,
`foco_provavel_incendio`, `padrao_queima`, `dano_termico`,
`fuligem_residuo`, `material_combustivel`, `supressao_vegetal`, `efluente`,
`indicador_queima`, `cadaver_animal`, `amostra_ambiental`,
`cartucho_municao`, `padrao_balistico`, `amostra_gsr`,
`arquivo_multimidia`, `equipamento_cftv`, `midia_armazenamento`,
`registro_audio`, `registro_video`, `registro_imagem`, `impressao_latente`,
`impressao_patente`, `impressao_moldada`, `registro_datiloscopico`,
`registro_palmar`, `fragmento_papilar`, `registro_necropapiloscopico`,
`outro`.

## 15. `medicoes.json`

Finalidade: medidas coletadas em campo.

Exemplo:

```json
[
  {
    "id": "med_001",
    "rotulo": "V1 ate ponto de impacto",
    "valor": 18.5,
    "unidade": "m",
    "ponto_a": "V1",
    "ponto_b": "Ponto de impacto",
    "metodo": "trena",
    "observacao": "",
    "fotos": ["foto_040"],
    "croqui": []
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno. |
| `rotulo` | string | Sim | Identificador/descricao da medida. |
| `valor` | numero | Sim | Valor numerico. |
| `unidade` | string | Sim | `m`, `cm`, `mm` ou texto livre. |
| `ponto_a` | string | Opcional | Origem da medida. |
| `ponto_b` | string | Opcional | Destino da medida. |
| `metodo` | string | Opcional | Exemplo: `trena`, `trena laser`, `estimado`, `outro`. |
| `observacao` | string | Opcional | Observacao livre. |
| `fotos` | lista de string | Sim | IDs de fotos vinculadas. |
| `croqui` | lista de string | Sim | Reservado para IDs de elementos do croqui. |

## 16. `observacoes.json`

Finalidade: notas livres do perito durante a ocorrencia.

Exemplo:

```json
[
  {
    "id": "nota_001",
    "criado_em": "2026-05-22T13:50:00.000",
    "editado_em": "2026-05-22T13:55:00.000",
    "texto": "Moradores informaram remocao previa de fragmentos.",
    "categoria": "pendencia",
    "prioridade": "importante"
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID interno. |
| `criado_em` | string ISO-8601 | Sim | Criacao da nota. |
| `editado_em` | string ISO-8601 | Sim | Ultima edicao. |
| `texto` | string | Sim | Texto livre. |
| `categoria` | string | Sim | Categoria da nota. |
| `prioridade` | string | Sim | `normal`, `importante`, `critica`. |

Categorias de nota:

`geral`, `local`, `veiculo`, `vitima`, `vestigio`, `dinamica`, `pendencia`,
`outro`.

## 17. `timeline.json`

Finalidade: historico automatico da ocorrencia.

Exemplo:

```json
[
  {
    "id": "timeline_created_123",
    "tipo": "ocorrencia_criada",
    "titulo": "Ocorrencia criada",
    "descricao": "Dossie operacional criado no aparelho.",
    "ocorrido_em": "2026-05-22T13:05:00.000"
  }
]
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `id` | string | Sim | ID do evento. |
| `tipo` | string | Sim | Tipo do evento automatico. |
| `titulo` | string | Sim | Titulo exibivel. |
| `descricao` | string | Opcional | Descricao complementar. |
| `ocorrido_em` | string ISO-8601 | Sim | Momento do evento. |

Tipos atuais:

`ocorrencia_criada`, `gps_iniciado`, `gps_capturado`, `primeira_foto`,
`exportacao`, `importacao`, `conclusao`, `reabertura`, `status_alterado`,
`arquivamento`.

## 18. `estatisticas.json`

Finalidade: estatisticas operacionais derivadas da ocorrencia. Estes dados
tambem podem ser recalculados pelo Desktop a partir dos demais JSONs, mas sao
incluidos para leitura direta e auditoria.

Exemplo parcial:

```json
{
  "ocorrencia_id": "occ_123",
  "tipo_pericia": "transito",
  "tipo_pericia_rotulo": "Transito",
  "natureza": "colisao",
  "natureza_rotulo": "Colisao",
  "resultado": "vitima_lesionada",
  "resultado_rotulo": "Com vitima lesionada",
  "status_ocorrencia": "exportada",
  "status_ocorrencia_rotulo": "Exportada",
  "status_operacional": "exportada",
  "criado_em": "2026-05-22T13:05:00.000",
  "iniciado_em": "2026-05-22T13:10:00.000",
  "concluido_em": "2026-05-22T14:20:00.000",
  "duracao_segundos": 4200,
  "municipio": "Macapa",
  "bairro": "Centro",
  "endereco": "Av. FAB - Centro - Macapa",
  "coordenada_principal": {
    "latitude": 0.0656487,
    "longitude": -51.0521516,
    "precisao_m": 4.3,
    "altitude_m": null,
    "capturado_em": "2026-05-22T13:30:00.000",
    "origem": "gps",
    "observacao": ""
  },
  "melhor_precisao_gps_m": 4.3,
  "total_fotos": 18,
  "total_vitimas_corpos": 1,
  "total_veiculos": 2,
  "total_vestigios": 3,
  "total_medicoes": 4,
  "total_observacoes": 2,
  "total_itens_checklist": 24,
  "itens_checklist_respondidos": 20,
  "itens_checklist_obrigatorios": 10,
  "itens_checklist_obrigatorios_pendentes": 1,
  "itens_nao_aplicaveis": 2,
  "exportada": true,
  "ultima_exportacao_em": "2026-05-22T14:30:10.000",
  "leituras_gps": 12,
  "distancia_aproximada_m": 45.2,
  "pendencias_encerramento": []
}
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `ocorrencia_id` | string | Sim | ID da ocorrencia. |
| `tipo_pericia` | string | Sim | Codigo do tipo. |
| `tipo_pericia_rotulo` | string | Sim | Rotulo para exibicao. |
| `natureza` | string | Opcional | Codigo da natureza. |
| `natureza_rotulo` | string | Opcional | Rotulo da natureza. |
| `resultado` | string | Sim | Codigo do resultado. |
| `resultado_rotulo` | string | Sim | Rotulo do resultado. |
| `status_ocorrencia` | string | Sim | Status atual. |
| `status_ocorrencia_rotulo` | string | Sim | Rotulo do status. |
| `status_operacional` | string | Sim | Status operacional. |
| `criado_em` | string ISO-8601 | Sim | Criacao. |
| `iniciado_em` | string ISO-8601 | Sim | Inicio efetivo. |
| `concluido_em` | string ISO-8601 ou null | Opcional | Conclusao. |
| `duracao_segundos` | inteiro | Sim | Duracao. |
| `municipio` | string | Opcional | Derivado de `caso.json`. |
| `bairro` | string | Opcional | Derivado de `caso.json`. |
| `endereco` | string | Opcional | Logradouro/bairro/municipio concatenados. |
| `coordenada_principal` | objeto ou null | Opcional | Mesmo formato de `localizacao.json`. |
| `melhor_precisao_gps_m` | numero ou null | Opcional | Melhor precisao. |
| `total_fotos` | inteiro | Sim | Quantidade de fotos no dossie. |
| `total_vitimas_corpos` | inteiro | Sim | Quantidade de vitimas/corpos. |
| `total_veiculos` | inteiro | Sim | Quantidade de veiculos. |
| `total_vestigios` | inteiro | Sim | Quantidade de vestigios. |
| `total_medicoes` | inteiro | Sim | Quantidade de medicoes. |
| `total_observacoes` | inteiro | Sim | Quantidade de observacoes. |
| `total_itens_checklist` | inteiro | Sim | Total de itens. |
| `itens_checklist_respondidos` | inteiro | Sim | Itens com resposta diferente de `nao_verificado`. |
| `itens_checklist_obrigatorios` | inteiro | Sim | Itens obrigatorios. |
| `itens_checklist_obrigatorios_pendentes` | inteiro | Sim | Obrigatorios pendentes. |
| `itens_nao_aplicaveis` | inteiro | Sim | Quantidade de modulos/itens marcados como nao aplicaveis. |
| `exportada` | booleano | Sim | Se ha registro de exportacao. |
| `ultima_exportacao_em` | string ISO-8601 ou null | Opcional | Data/hora da ultima exportacao. |
| `leituras_gps` | inteiro | Sim | Total de leituras GPS. |
| `distancia_aproximada_m` | numero ou null | Opcional | Distancia aproximada calculada pela trilha. |
| `pendencias_encerramento` | lista | Sim | Avisos nao bloqueantes de conclusao. |

## 19. `operacional.json`

Finalidade: estado operacional do dossie, progresso, modulos, fluxo sugerido,
nao aplicaveis e sessao operacional.

Exemplo parcial:

```json
{
  "percentual": 80,
  "itens_concluidos": 8,
  "itens_totais": 10,
  "pendencias": ["Checklist com obrigatorios pendentes"],
  "nao_aplicavel": ["victims", "measurements"],
  "fluxo_sugerido": [
    {
      "id": "gps",
      "titulo": "GPS",
      "descricao": "Coordenada pericial salva no dossie",
      "estado": "concluido"
    }
  ],
  "modulos": [
    {
      "id": "gps",
      "titulo": "GPS",
      "estado": "concluido",
      "aplicavel": true
    }
  ],
  "sessao": {
    "status_operacional": "exportada",
    "status_ocorrencia": "exportada",
    "iniciado_em": "2026-05-22T13:10:00.000",
    "concluido_em": "2026-05-22T14:20:00.000",
    "duracao_segundos": 4200,
    "gps_melhor_leitura": null,
    "gps_total_leituras": 12,
    "distancia_aproximada_m": 45.2,
    "pendencias_encerramento": [],
    "estatisticas": {}
  }
}
```

Campos principais:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `percentual` | inteiro | Sim | Progresso operacional de 0 a 100. |
| `itens_concluidos` | inteiro | Sim | Itens resolvidos. |
| `itens_totais` | inteiro | Sim | Itens considerados no fluxo. |
| `pendencias` | lista de string | Sim | Pendencias operacionais nao bloqueantes. |
| `nao_aplicavel` | lista de string | Sim | IDs de modulos marcados como nao aplicaveis. |
| `fluxo_sugerido` | lista de objeto | Sim | Etapas orientativas. |
| `modulos` | lista de objeto | Sim | Estado resumido dos modulos. |
| `sessao` | objeto | Sim | Dados da sessao operacional. |

Estados de modulo/etapa:

`pendente`, `parcial`, `concluido`, `nao_aplicavel`.

IDs operacionais atuais:

`case_data`, `gps`, `checklist`, `photos`, `trace_photos`, `vehicles`,
`victims`, `traces`, `biological_traces`, `ballistic_traces`,
`weapons_objects`, `measurements`, `notes`, `export`.

Campos de `sessao`:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `status_operacional` | string | Sim | Status operacional. |
| `status_ocorrencia` | string | Sim | Status da ocorrencia. |
| `iniciado_em` | string ISO-8601 | Sim | Inicio efetivo. |
| `concluido_em` | string ISO-8601 ou null | Opcional | Conclusao. |
| `duracao_segundos` | inteiro | Sim | Duracao. |
| `gps_melhor_leitura` | objeto ou null | Opcional | Melhor leitura GPS. |
| `gps_total_leituras` | inteiro | Sim | Total de leituras. |
| `distancia_aproximada_m` | numero ou null | Opcional | Distancia aproximada. |
| `pendencias_encerramento` | lista | Sim | Avisos nao bloqueantes. |
| `estatisticas` | objeto | Sim | Copia de `estatisticas.json`. |

## 20. `hashes.json`

Finalidade: verificar integridade dos arquivos do pacote.

Exemplo:

```json
{
  "algoritmo": "SHA-256",
  "arquivos": [
    {
      "caminho": "caso.json",
      "sha256": "f2ab..."
    },
    {
      "caminho": "fotos/foto_001.jpg",
      "sha256": "a3f0..."
    }
  ],
  "observacao": "hashes.json nao inclui o proprio arquivo para evitar referencia circular."
}
```

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `algoritmo` | string | Sim | Hoje: `SHA-256`. |
| `arquivos` | lista de objeto | Sim | Lista de caminhos e hashes. |
| `observacao` | string | Sim | Explica ausencia do proprio `hashes.json`. |

Cada item de `arquivos`:

| Campo | Tipo | Obrigatorio | Observacao |
| --- | --- | --- | --- |
| `caminho` | string | Sim | Caminho relativo no pacote. |
| `sha256` | string | Sim | Hash SHA-256 hexadecimal. |

Regras:

- `hashes.json` nao possui hash de si mesmo.
- `manifest.json` e os demais JSONs sao hashados.
- Fotos incluidas fisicamente em `fotos/` sao hashadas.
- Fotos ausentes no aparelho podem aparecer em `fotos.json` com
  `arquivo_disponivel = false`, sem binario correspondente.

## 21. Tudo Que O SICRO Operacional Salva Hoje

Salvo e exportado no `.sicroapp` atual:

- Dados do caso: `caso.json`.
- Tipo de pericia e metadados: `metadados.json`.
- Metadados de transito: natureza, envolvidos, indicador de veiculo oficial e
  resultado.
- Metadados de local de crime: natureza, estado do corpo/vitima, quantidade,
  ambiente e vestigios esperados.
- Metadados de patrimonio: natureza de patrimonio.
- Metadados ambientais: natureza, contexto do local e vestigios esperados.
- Metadados de balistica forense: natureza, contexto e elementos balisticos
  esperados.
- Metadados de audio e imagem: natureza, contexto e elementos multimidia
  esperados.
- Metadados de papiloscopia: natureza, contexto e vestigios papiloscopicos
  esperados.
- Localizacao principal: `localizacao.json`.
- Trilha/leituras GPS: `gps_leituras.json`.
- Fotos categorizadas: `fotos.json` e pasta `fotos/`.
- Vinculos de fotos: listas `fotos` em veiculos, vitimas, vestigios e medicoes.
- Checklist contextual e editavel por ocorrencia: `checklist.json`.
- Veiculos: `veiculos.json`.
- Vitimas/corpos: `vitimas.json`.
- Vestigios: `vestigios.json`.
- Medicoes: `medicoes.json`.
- Observacoes/notas: `observacoes.json`.
- Estatisticas operacionais: `estatisticas.json`.
- Timeline automatica: `timeline.json`.
- Status, progresso, nao aplicaveis e sessao: `operacional.json`.
- Integridade por hashes: `hashes.json`.

Salvo localmente no app, mas nao exportado no `.sicroapp` atual:

- Perfil global do perito/configuracoes iniciais.
- Areas ativas do app.
- Relatorio de plantao PDF.
- Relatorio estatistico PDF.
- Preferencias visuais ou configuracoes locais.

Reservado/preparado, mas ainda sem arquivo exportado:

- `croqui_rapido.json`.
- `auditoria.json`.
- Vinculos espaciais reais com elementos do croqui Desktop.

## 22. O Que O SICRO Desktop Deve Conseguir Ler

### Nivel 1 - Importacao Minima

Objetivo: abrir o pacote e criar um painel basico de dossie de campo.

Ler:

- `manifest.json`.
- `metadados.json`.
- `caso.json`.
- `localizacao.json`.
- `fotos.json` e binarios em `fotos/`.
- `observacoes.json`.
- `hashes.json` para validacao basica.

Resultado no Desktop:

- Criar objeto interno `DossieOperacional`.
- Exibir resumo da ocorrencia.
- Exibir coordenada principal.
- Exibir galeria de fotos categorizadas.
- Exibir observacoes.
- Permitir abrir pasta/visualizador de fotos.

### Nivel 2 - Dossie Completo

Objetivo: importar todo o conteudo operacional do app.

Ler tambem:

- `checklist.json`.
- `veiculos.json`.
- `vitimas.json`.
- `vestigios.json`.
- `medicoes.json`.
- `gps_leituras.json`.
- `timeline.json`.
- `estatisticas.json`.
- `operacional.json`.
- Vinculos de fotos por ID.
- Modulos marcados como `nao_aplicavel`.

Resultado no Desktop:

- Exibir checklist com respostas e observacoes.
- Exibir entidades e fotos vinculadas.
- Exibir vestigios e medicoes.
- Exibir timeline.
- Exibir estatisticas do atendimento.
- Manter rastreabilidade entre foto, entidade e dado de campo.

### Nivel 3 - Integracao Avancada Futura

Objetivo: transformar o dossie operacional em insumo ativo do SICRO Desktop.

Possibilidades:

- Abrir mapa/OSM pela coordenada principal.
- Sugerir base cartografica a partir de latitude/longitude.
- Criar painel "Dossie de Campo" no Desktop.
- Vincular fotos a elementos do croqui.
- Sugerir elementos iniciais no croqui com base em veiculos, vestigios e
  medicoes.
- Pre-preencher campos de prancha/laudo com dados do caso.
- Gerar relatorios internos e estatisticas no Desktop.
- Comparar pacotes de uma mesma ocorrencia por hash/timeline.

## 23. Riscos De Integracao

### Campos ausentes ou vazios

Nem toda ocorrencia possui vitimas, veiculos, vestigios, medicoes ou fotos de
vestigio. O Desktop deve diferenciar:

- arquivo de modulo ausente: pacote antigo ou corrompido;
- arquivo presente com lista vazia: modulo sem registros;
- modulo em `nao_aplicavel`: decisao operacional do perito.

### Nomes e acentos

Os codigos internos sao ASCII e estaveis. Rotulos podem mudar. O Desktop deve
usar os codigos como fonte de verdade, nao os rotulos.

### IDs locais

IDs sao estaveis dentro do pacote, mas nao devem ser tratados como globais entre
pacotes. Ao importar multiplos pacotes, o Desktop deve criar um namespace por
pacote/ocorrencia.

### Caminhos locais de fotos

No `.sicroapp`, `fotos.json.arquivo` aponta para caminho relativo dentro do ZIP.
O Desktop nao deve esperar caminho Android original.

### Fotos ausentes

Se `arquivo_disponivel = false`, a foto existia no cadastro, mas o binario nao
foi localizado no aparelho durante a exportacao. O Desktop deve exibir aviso e
seguir com importacao parcial.

### Hashes

Inconsistencia de hash indica pacote alterado/corrompido. Recomendacao:

- erro bloqueante para JSON critico corrompido;
- erro bloqueante para foto com hash divergente quando ela sera usada como
  evidencia;
- importacao parcial apenas quando a politica institucional permitir.

### Versao do pacote

Versao atual e `0.7`. O Desktop deve validar `manifest.versao`, aceitar
versoes listadas em `manifest.versoes_compativeis` e registrar aviso para
versoes maiores desconhecidas.

### `.sicrocampo` legado

Novas exportacoes usam `.sicroapp`. O Desktop deve aceitar `.sicrocampo` como
ZIP compativel quando o `manifest.formato` for `sicrocampo` ou quando o pacote
seguir estrutura equivalente.

### Dados especificos por tipo de pericia

O Desktop deve tratar `tipo_pericia` como chave de contexto:

- `transito`: veiculos e vestigios de transito tendem a ser centrais.
- `morte_violenta`: vitimas/corpos, vestigios biologicos/balisticos e armas
  ganham prioridade.
- `patrimonio`: fotos, vestigios, medicoes e observacoes sao centrais.
- `ambiental`: checklist ambiental, fotos, vestigios ambientais, medicoes,
  observacoes, amostras/coletas e cadeia de custodia ganham prioridade.
- `balistica_forense`: recebimento/custodia, seguranca, armas, municoes,
  cartuchos, estojos, projeteis, padroes balisticos e GSR ganham prioridade.
- `audio_imagem`: midias originais, arquivos multimidia, CFTV, metadados,
  hashes, material padrao, quadros/frames, audio e video ganham prioridade,
  preparando integracao futura com analise de audio, video e imagem no Desktop.
- `papiloscopia`: identificacao criminal, levantamento em local, laboratorio,
  necropapiloscopia, vestigios latentes/patentes/moldados, suportes,
  decalques, qualidade para AFIS/ABIS e cadeia de custodia ganham prioridade.

### Evolucao futura

Novos JSONs podem ser adicionados sem quebrar importadores antigos. O Desktop
deve ignorar arquivos desconhecidos e preservar, se possivel, uma copia bruta do
pacote original.

## 24. Contrato Proposto Para Importacao No SICRO Desktop

Fluxo recomendado:

1. Receber caminho do arquivo `.sicroapp` ou `.sicrocampo`.
2. Validar se o arquivo e ZIP legivel.
3. Abrir `manifest.json`.
4. Validar `formato`, `versao` e lista de arquivos.
5. Ler `hashes.json`.
6. Calcular SHA-256 dos arquivos listados, exceto `hashes.json`.
7. Classificar resultado de integridade:
   - `integro`;
   - `integro_com_avisos`;
   - `parcial`;
   - `corrompido`.
8. Extrair fotos para pasta controlada do Desktop, nunca para pasta temporaria
   volatil sem controle.
9. Criar objeto interno `DossieOperacional`.
10. Resolver vinculos de fotos por ID.
11. Exibir tela de pre-importacao com resumo e avisos.
12. Confirmar importacao.
13. Salvar pacote original ou seu hash junto ao registro importado.

Modelo interno sugerido:

```text
DossieOperacional
|-- pacote
|   |-- formato
|   |-- versao
|   |-- arquivo_origem
|   |-- sha256_pacote
|   |-- importado_em
|-- caso
|-- metadados
|-- localizacao
|-- gps_leituras
|-- fotos
|-- checklist
|-- entidades
|   |-- veiculos
|   |-- vitimas_corpos
|-- vestigios
|-- medicoes
|-- observacoes
|-- timeline
|-- estatisticas
|-- operacional
|-- avisos_integridade
```

Abas sugeridas no Desktop:

- Resumo.
- Fotos.
- Checklist.
- Entidades.
- Vestigios.
- Medicoes.
- Observacoes.
- Timeline.
- Estatisticas.

## 25. Roadmap De Integracao Com SICRO Desktop

### Fase A - Leitor tecnico

- Abrir ZIP.
- Ler manifest.
- Validar hashes.
- Listar conteudo.
- Exibir resumo em tela simples.

### Fase B - Importacao minima

- Importar caso, metadados, localizacao, fotos e observacoes.
- Copiar fotos para pasta controlada do projeto Desktop.
- Criar painel "Dossie de Campo".

### Fase C - Dossie completo

- Importar checklist, entidades, vestigios, medicoes, timeline e estatisticas.
- Resolver vinculos de fotos.
- Permitir navegacao por abas.

### Fase D - Integracao com croqui

- Abrir mapa pela coordenada.
- Sugerir cena base.
- Permitir arrastar fotos/vestigios para elementos do croqui.
- Criar referencias cruzadas entre foto, vestigio, medicao e desenho.

### Fase E - Relatorio e inteligencia operacional

- Pre-preencher dados da prancha/laudo.
- Gerar painel estatistico desktop.
- Cruzar ocorrencias por periodo, municipio, tipo e natureza.
- Preparar sincronizacao futura, se desejado.

## 26. Recomendacoes Para Compatibilidade

- Manter `manifest.json` como arquivo obrigatorio.
- Manter `metadados.json`, `caso.json`, `fotos.json`, `observacoes.json` como
  base da importacao minima.
- Seguir a politica de compatibilidade em `docs/SICROAPP_COMPATIBILITY_POLICY.md`.
- Para mudancas aditivas, incrementar minor do formato.
- Para mudancas breaking, alinhar previamente com o SICRO Desktop e incrementar
  major do formato.
- Nunca renomear, remover, mover ou mudar tipo de campo existente sem manter
  compatibilidade por alias.
- Nao depender de ordem dos arquivos dentro do ZIP.
- Aceitar arquivos JSON extras.
- Preservar IDs originais dentro do dossie importado.
- Criar ID interno proprio no Desktop para evitar colisao entre importacoes.
- Guardar hash do pacote original.
- Exibir avisos de integridade ao usuario.
- Tratar ausencia de modulo como "nao informado", e `nao_aplicavel` como uma
  decisao operacional registrada.

## 27. Fontes Auditadas No Codigo

Arquivos principais usados nesta especificacao:

- `lib/core/data/sicrocampo_package_contract.dart`
- `lib/core/data/sicrocampo_export_service.dart`
- `lib/core/data/sicroapp_import_service.dart`
- `lib/domain/models/occurrence.dart`
- `lib/domain/models/forensic_case_metadata.dart`
- `lib/domain/models/case_data.dart`
- `lib/domain/models/location_record.dart`
- `lib/domain/models/checklist_item.dart`
- `lib/domain/models/field_photo.dart`
- `lib/domain/models/vehicle_record.dart`
- `lib/domain/models/victim_record.dart`
- `lib/domain/models/trace_record.dart`
- `lib/domain/models/measurement_record.dart`
- `lib/domain/models/field_note.dart`
- `lib/domain/models/app_settings.dart`

## 28. Changelog Do Contrato

### `0.7`

Mudancas aditivas compativeis:

- Adicionado `metadados.json.veiculo_oficial` para ocorrencias de transito
  envolvendo carro/veiculo oficial.
- Adicionada categoria de checklist `croqui_levantamento`.
- Adicionados itens base de checklist de transito:
  `metodo_croqui_registrado`, `levantamento_drone_realizado` e
  `croqui_manual_trena`.
- `manifest.json.versoes_compativeis` passa a listar `0.1`, `0.2`, `0.3`,
  `0.4`, `0.5`, `0.6` e `0.7`.

### `0.6`

Mudancas aditivas compativeis:

- Adicionado tipo de pericia `papiloscopia`.
- Adicionado subobjeto condicional `metadados.json.papiloscopia`.
- Adicionados catalogos de papiloscopia: natureza, contexto e vestigios
  esperados.
- Adicionados tipos de vestigio papiloscopico: `impressao_latente`,
  `impressao_patente`, `impressao_moldada`, `registro_datiloscopico`,
  `registro_palmar`, `fragmento_papilar` e `registro_necropapiloscopico`.
- Adicionadas categorias de checklist de papiloscopia: biosseguranca, coleta,
  revelacao, identificacao, laboratorio e necropapiloscopia.
- `manifest.json.versoes_compativeis` passa a listar `0.1`, `0.2`, `0.3`,
  `0.4`, `0.5` e `0.6`.

### `0.5`

Mudancas aditivas compativeis:

- Adicionado tipo de pericia `audio_imagem`.
- Adicionado subobjeto condicional `metadados.json.audio_imagem`.
- Adicionados catalogos de audio e imagem: natureza, contexto e vestigios
  esperados.
- Adicionados tipos de vestigio/midia: `arquivo_multimidia`,
  `equipamento_cftv`, `midia_armazenamento`, `registro_audio`,
  `registro_video`, `registro_imagem`.
- Adicionadas categorias de checklist de audio e imagem: recebimento,
  preservacao digital, adequabilidade, processamento, coleta CFTV,
  comparacao facial, comparacao de locutor e verificacao de edicao.
- `manifest.json.versoes_compativeis` passa a listar `0.1`, `0.2`, `0.3`,
  `0.4` e `0.5`.

### `0.4`

Mudancas aditivas compativeis:

- Adicionado tipo de pericia `balistica_forense`.
- Adicionado subobjeto condicional `metadados.json.balistica_forense`.
- Adicionados catalogos de balistica forense: natureza, contexto e vestigios
  esperados.
- Adicionados tipos de vestigio balistico: `cartucho_municao`,
  `padrao_balistico`, `amostra_gsr`.
- Adicionadas categorias de checklist de balistica: recebimento/custodia,
  seguranca, armas de fogo, municoes, coleta GSR e confronto balistico.
- `manifest.json.versoes_compativeis` passa a listar `0.1`, `0.2`, `0.3` e
  `0.4`.

### `0.3`

Mudancas aditivas compativeis:

- Adicionado tipo de pericia `ambiental`.
- Adicionado subobjeto condicional `metadados.json.ambiental`.
- Adicionados catalogos ambientais: natureza, contexto do local e vestigios
  esperados.
- Adicionados tipos de vestigio ambiental: `supressao_vegetal`, `efluente`,
  `indicador_queima`, `cadaver_animal`, `amostra_ambiental`.
- Adicionadas categorias de checklist ambiental: planejamento, local, dano,
  amostras/coleta e cadeia de custodia.
- `manifest.json.versoes_compativeis` passa a listar `0.1`, `0.2` e `0.3`.

### `0.2`

Mudancas aditivas compativeis:

- Adicionado `manifest.json.versoes_compativeis`.
- Adicionado `caso.json.tecnico_pericial`.
- Mantido `caso.json.equipe_apoio` como alias legado de `tecnico_pericial`.
- Adicionado `caso.json.equipe_policial`.
- Adicionado `caso.json.comandante_policial`.
- Adicionado `veiculos.json[].ponto_impacto`.
- Adicionados tipos de vestigio `derrapagem` e `marca_impacto`.
- Mantido codigo `sulco`, com rotulo atualizado para `Sulcagem/sulco`.

### `0.1`

Primeiro contrato documentado do pacote `.sicroapp`, com manifest, metadados,
caso, localizacao, GPS, fotos, checklist, veiculos, vitimas, vestigios,
medicoes, observacoes, operacional, estatisticas, timeline e hashes.
