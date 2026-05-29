class SicroCampoPackageContract {
  static const format = 'sicroapp';
  static const legacyFormat = 'sicrocampo';
  static const version = '0.8';
  static const compatibleVersions = [
    '0.1',
    '0.2',
    '0.3',
    '0.4',
    '0.5',
    '0.6',
    '0.7',
    version,
  ];
  static const extension = '.sicroapp';
  static const legacyExtension = '.sicrocampo';
  static const compatibleExtensions = [extension, legacyExtension];

  static const manifest = 'manifest.json';
  static const metadata = 'metadados.json';
  static const caseData = 'caso.json';
  static const location = 'localizacao.json';
  static const gpsTrack = 'gps_leituras.json';
  static const statistics = 'estatisticas.json';
  static const timeline = 'timeline.json';
  static const checklist = 'checklist.json';
  static const photos = 'fotos.json';
  static const vehicles = 'veiculos.json';
  static const victims = 'vitimas.json';
  static const traces = 'vestigios.json';
  static const measurements = 'medicoes.json';
  static const notes = 'observacoes.json';
  static const officialDocuments = 'oficios.json';
  static const operational = 'operacional.json';
  static const quickSketch = 'croqui_rapido.json';
  static const audit = 'auditoria.json';
  static const hashes = 'hashes.json';
  static const photosDirectory = 'fotos/';
  static const officialDocumentsDirectory = 'oficios/';
}
