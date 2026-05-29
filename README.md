# SICRO Operacional

Aplicativo mobile offline-first para apoiar o trabalho pericial em campo,
organizando ocorrencias, registros fotograficos, checklists, oficios, plantoes,
relatorios e pacotes de integracao com o ecossistema SICRO.

Versao atual: `1.0.0+1` - piloto operacional Android.

## Objetivo

O SICRO Operacional funciona como uma memoria viva da atividade pericial. Ele
ajuda o perito a registrar informacoes no local, acompanhar pendencias,
consultar historico, gerar relatorios e preservar dados para estudo posterior no
SICRO Desktop.

O fluxo principal e:

```text
local da pericia -> dossie operacional -> relatorios / .sicroapp / backup
```

## Principais recursos

- Diario operacional com ocorrencias agrupadas por mes.
- Criacao guiada de pericias por area de atuacao.
- Tipos de pericia:
  - transito;
  - local de crime;
  - patrimonio;
  - ambiental;
  - balistica forense;
  - audio e imagem;
  - papiloscopia.
- Dados do caso, equipe, local, BO, requisicao, protocolo e observacoes.
- GPS pericial com melhor leitura, precisao e trilha operacional.
- Captura de fotos categorizadas.
- Vinculo de fotos com veiculos, vitimas/corpos, vestigios e medicoes.
- Checklists contextuais por tipo de pericia.
- Checklist editavel por ocorrencia, permitindo adicionar, editar e remover
  perguntas.
- Registros de veiculos, vitimas/corpos, vestigios, medicoes e notas de campo.
- Status operacional, encerramento da pericia, estatisticas e timeline
  automatica.
- Exportacao e importacao de pacotes `.sicroapp`.
- Backup completo do app em pacote `.sicrobackup`.

## Relatorio de plantao

O app permite selecionar ocorrencias de um intervalo de plantao e gerar PDF
institucional automaticamente.

Recursos atuais:

- filtro por data e horario do plantao;
- inclusao de ocorrencias iniciadas ate 2 horas apos o fim do intervalo, com
  indicacao visual de que estao fora da janela original;
- modelo classico institucional;
- modelo operacional SICRO com foto principal, coordenadas, resumo da ocorrencia
  e dados coletados;
- compartilhamento/salvamento do PDF pelo Android.

## Agenda de plantoes

O SICRO Operacional tambem possui modulo de agenda para acompanhamento de
plantoes.

Recursos atuais:

- cadastro e consulta de plantoes;
- lembretes/notificacoes;
- importacao de escala em PDF;
- leitura da escala para identificar plantoes do perito informado;
- preparacao para organizacao mensal e acompanhamento pessoal da rotina.

## Oficios

O modulo de oficios foi criado para reduzir preenchimento manual e organizar
prazos/documentos recebidos fisicamente.

Recursos atuais:

- captura de foto do oficio;
- OCR para leitura automatica;
- extracao assistida de dados relevantes;
- cadastro do oficio com prazo e informacoes essenciais;
- acesso posterior a foto original do documento;
- historico local de oficios recebidos.

## Estatisticas

O app calcula estatisticas locais a partir dos dados ja registrados, sem exigir
preenchimento extra do perito.

Inclui:

- quantidade de pericias por periodo;
- pericias por tipo e natureza;
- tempo medio de atendimento;
- totais de fotos, vestigios, medicoes, vitimas/corpos, veiculos e observacoes;
- relatorio estatistico em PDF.

## Integracao SICRO

O formato `.sicroapp` e um pacote ZIP estruturado com JSONs, fotos, manifest e
hashes. Ele foi pensado para permitir que o SICRO Desktop leia o dossie
operacional gerado em campo.

O formato `.sicrobackup` armazena dados do aparelho para migracao ou seguranca,
incluindo ocorrencias, oficios, plantoes, relatorios e midias.

## Rodar em desenvolvimento

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run
```

## Validacao

```powershell
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
```

## Documentacao

- Especificacao do pacote: `docs/SICROAPP_FORMAT_SPEC.md`.
- Integracao Desktop 2.0: `docs/SICRO_OPERACIONAL_INTEGRACAO_DESKTOP_2.md`.
- Roteiro de piloto: `docs/PILOTO_V0_1_ROTEIRO_TESTE.md`.
- Notas da versao piloto: `docs/RELEASE_PILOTO_V0_1.md`.
