# SICRO Operacional - Revisao de Compatibilidade iOS

## Estado atual

- Scaffold iOS criado em `ios/`.
- App name iOS configurado como `SICRO Operacional`.
- Bundle Identifier inicial: `br.gov.ap.policiacientifica.sicrooperacional`.
- Permissoes iOS adicionadas em `ios/Runner/Info.plist`.
- `ios/Podfile` configurado com iOS 15.5.
- Deployment target do Runner ajustado para iOS 15.5.
- Tipos de arquivo `.sicroapp`, `.sicrocampo` e `.sicrobackup` registrados no iOS.
- Ponte nativa iOS adicionada para abrir pacotes externos e selecionar PDF/backup.
- Icones iOS gerados a partir da identidade visual em `assets/launcher/app_icon.png`.
- Compartilhamento ajustado com `sharePositionOrigin` para reduzir risco de falha do share sheet em iPad.

## Plugins e compatibilidade

| Recurso | Plugin/camada | Situacao iOS |
| --- | --- | --- |
| GPS/localizacao | `geolocator` | Compativel. Requer `NSLocationWhenInUseUsageDescription`. Background tracking futuro exigira `UIBackgroundModes` e revisao de UX/permissao. |
| Camera | `image_picker` | Compativel. Requer `NSCameraUsageDescription`. |
| Fotos/galeria futura | `image_picker` | Preparado com `NSPhotoLibraryUsageDescription` e `NSPhotoLibraryAddUsageDescription`. O fluxo atual usa camera, nao galeria. |
| Persistencia local | `path_provider` + `dart:io` | Compativel. Usa sandbox local do app. |
| Exportacao `.sicroapp` | `archive`, `crypto`, `dart:io` | Compativel. Gera ZIP renomeado dentro do sandbox. |
| Importacao `.sicroapp`/`.sicrobackup` | Swift + `MethodChannel` | Ponte iOS criada. Precisa validacao em iPhone real. |
| Seletor de PDF/backup | Swift + `UIDocumentPickerViewController` | Ponte iOS criada. Precisa validacao em iPhone real. |
| Compartilhamento | `share_plus` | Compativel. Testar em iPhone/iPad real pelo share sheet. |
| PDF | `pdf` + `dart:io` | Compativel. Gera PDF offline. |
| OCR de oficios | `google_mlkit_text_recognition` | Compativel com iOS 15.5+. Exige CocoaPods/Xcode no Mac. |

## Permissoes configuradas

- `NSCameraUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

## Pontos que podem exigir adaptacao

- GPS continuo em primeiro plano deve funcionar, mas precisa teste real em iPhone com tela bloqueando, app em segundo plano e troca de apps.
- Background location ainda nao esta habilitado oficialmente. Para isso sera necessario adicionar `UIBackgroundModes = location`, ajustar `geolocator` com configuracao iOS propria e justificar muito bem a permissao.
- O app usa visual Material. Deve renderizar no iOS, mas a validacao visual precisa cobrir safe areas, teclado, bottom sheets e share sheet.
- O Bundle Identifier deve ser confirmado no Apple Developer antes de TestFlight.
- A ponte Swift foi preparada no Windows, mas a compilacao real so pode ser validada no Mac.

## Proximos passos em um Mac

1. Abrir `ios/Runner.xcworkspace` no Xcode.
2. Selecionar o time Apple Developer.
3. Confirmar Bundle Identifier `br.gov.ap.policiacientifica.sicrooperacional`.
4. Rodar `flutter pub get`.
5. Rodar `cd ios && pod install --repo-update && cd ..`.
6. Rodar `flutter build ios --debug` ou executar em iPhone fisico.
7. Testar GPS, camera, OCR, exportacao/importacao `.sicroapp`, backup, PDFs e compartilhamento.
