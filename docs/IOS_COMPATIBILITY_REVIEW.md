# SICRO Operacional - Revisao de Compatibilidade iOS

## Estado atual

- Scaffold iOS criado em `ios/`.
- App name iOS configurado como `SICRO Operacional`.
- Bundle Identifier inicial: `br.gov.ap.policiacientifica.sicrooperacional`.
- Permissoes iOS adicionadas em `ios/Runner/Info.plist`.
- Compartilhamento ajustado com `sharePositionOrigin` para reduzir risco de falha do share sheet em iPad.

## Plugins e compatibilidade

| Recurso | Plugin/camada | Situacao iOS |
| --- | --- | --- |
| GPS/localizacao | `geolocator` | Compativel. Requer `NSLocationWhenInUseUsageDescription`. Background tracking futuro exigira `UIBackgroundModes` e revisao de UX/permissao. |
| Camera | `image_picker` | Compativel. Requer `NSCameraUsageDescription`. |
| Fotos/galeria futura | `image_picker` | Preparado com `NSPhotoLibraryUsageDescription` e `NSPhotoLibraryAddUsageDescription`. O fluxo atual usa camera, nao galeria. |
| Persistencia local | `path_provider` + `dart:io` | Compativel. Usa sandbox local do app. |
| Exportacao `.sicroapp` | `archive`, `crypto`, `dart:io` | Compativel. Gera ZIP renomeado dentro do sandbox. |
| Compartilhamento | `share_plus` | Compativel. Testar em iPhone/iPad real pelo share sheet. |
| PDF | `pdf` + `dart:io` | Compativel. Gera PDF offline. |

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
- Icone e splash gerados ainda sao os padroes do Flutter; precisam receber a identidade visual oficial antes de piloto iOS.

## Proximos passos em um Mac

1. Abrir `ios/Runner.xcworkspace` no Xcode.
2. Selecionar o time Apple Developer.
3. Confirmar Bundle Identifier `br.gov.ap.policiacientifica.sicrooperacional`.
4. Rodar `flutter pub get`.
5. Rodar `flutter build ios --debug` ou executar em iPhone fisico.
6. Testar GPS, camera, exportacao `.sicroapp`, PDFs e compartilhamento.
7. Preparar icone/splash oficiais antes de TestFlight.
