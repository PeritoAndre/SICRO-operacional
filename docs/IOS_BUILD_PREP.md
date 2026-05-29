# SICRO Operacional - Preparacao iOS

Este documento organiza o roteiro para compilar e validar o SICRO Operacional em iPhone usando macOS/Xcode.

## Estado preparado no projeto

- Bundle Identifier inicial: `br.gov.ap.policiacientifica.sicrooperacional`.
- Nome do app: `SICRO Operacional`.
- iOS Deployment Target: `15.5`.
- `ios/Podfile` configurado para iOS 15.5 por exigencia do ML Kit OCR.
- Permissoes em `Info.plist`:
  - camera;
  - localizacao quando em uso;
  - fotos/galeria.
- Tipos de arquivo registrados no iOS:
  - `.sicroapp`;
  - `.sicrocampo`;
  - `.sicrobackup`.
- Ponte nativa iOS criada para:
  - abrir pacotes recebidos por Arquivos/AirDrop/WhatsApp;
  - copiar o arquivo para o sandbox do app;
  - selecionar PDF de escala;
  - selecionar backup `.sicrobackup`.
- Icones iOS gerados a partir de `assets/launcher/app_icon.png`.

## Preparacao do Mac

1. Instalar Xcode pela App Store.
2. Abrir Xcode uma vez e aceitar termos/componentes.
3. Instalar Flutter no Mac.
4. Instalar CocoaPods:

```sh
sudo gem install cocoapods
```

5. Rodar:

```sh
flutter doctor -v
```

Resolver pendencias de Xcode/CocoaPods antes de continuar.

## Primeiro build local

Na pasta do projeto:

```sh
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter run -d <ID_DO_IPHONE>
```

Se preferir abrir no Xcode:

```sh
open ios/Runner.xcworkspace
```

No Xcode:

1. Selecionar `Runner`.
2. Em `Signing & Capabilities`, escolher o Team Apple Developer.
3. Confirmar Bundle Identifier `br.gov.ap.policiacientifica.sicrooperacional`.
4. Selecionar o iPhone fisico.
5. Clicar em Run.

## Checklist de validacao em iPhone fisico

- Abrir o app pela primeira vez.
- Criar uma pericia de transito.
- Criar uma pericia de local de crime.
- Capturar foto.
- Rodar OCR de oficio.
- Capturar GPS.
- Gerar relatorio de plantao.
- Gerar relatorio estatistico.
- Exportar `.sicroapp`.
- Compartilhar `.sicroapp` por Arquivos/AirDrop/WhatsApp.
- Abrir `.sicroapp` recebido no proprio iPhone.
- Importar `.sicroapp` como ocorrencia local.
- Importar PDF de escala de plantao.
- Gerar `.sicrobackup`.
- Abrir/restaurar `.sicrobackup`.
- Agendar notificacao de plantao.
- Agendar lembrete de backup.

## Build para TestFlight

Depois de validar em debug:

```sh
flutter build ipa --release
```

Ou pelo Xcode:

1. `Product > Archive`.
2. Abrir Organizer.
3. `Distribute App`.
4. Enviar para App Store Connect/TestFlight.

## Pontos de atencao

- O OCR depende do ML Kit e exige iOS 15.5 ou superior.
- A primeira compilacao pode demorar por causa dos pods.
- O iOS nao permite escrever livremente fora do sandbox; exportacao deve sair via share sheet.
- Abertura de `.sicroapp` e `.sicrobackup` precisa ser testada com arquivos vindos de fora do app.
- Background GPS ainda nao esta habilitado; o rastreio atual e de uso em primeiro plano/sessao ativa.
- Antes de publicar fora do TestFlight, revisar as respostas de privacidade da App Store.
