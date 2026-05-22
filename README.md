# SICRO Operacional

Aplicativo Android-first para dossies periciais operacionais, integrado ao
SICRO desktop por meio de pacotes `.sicroapp`.

Versao atual: `1.0.0-alpha+1` - alpha Android.

## Objetivo

O SICRO Operacional organiza dados do caso, GPS, checklist, fotos, veiculos,
vitimas, vestigios, medicoes, observacoes e relatorio de plantao durante o
atendimento pericial.
O produto inicial e o ciclo:

```text
local da pericia -> dossie operacional -> .sicroapp -> SICRO desktop
```

## Escopo v0.1

- Flutter.
- Android-first.
- Offline-first.
- Gestao de ocorrencias.
- Dados do caso.
- Checklist contextual e editavel por ocorrencia.
- Relatorio de plantao em PDF.
- Telemetria operacional passiva por ocorrencia.
- Encerramento operacional formal com timeline automatica.
- Estatisticas locais agregadas por periodo, tipo e status.
- Relatorio estatistico operacional em PDF.
- Base para fotos, GPS, veiculos, vitimas, vestigios, medicoes e exportacao.

## Rodar

```powershell
C:\flutter\bin\flutter.bat run
```

## Especificacao

Veja `docs/SICRO_OPERACIONAL_V0_1_SPEC.md`.

## Piloto interno

- Roteiro de teste: `docs/PILOTO_V0_1_ROTEIRO_TESTE.md`.
- Notas da versao piloto: `docs/RELEASE_PILOTO_V0_1.md`.
