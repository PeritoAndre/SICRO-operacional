import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class AudioImageSetupScreen extends StatefulWidget {
  const AudioImageSetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<AudioImageSetupScreen> createState() => _AudioImageSetupScreenState();
}

class _AudioImageSetupScreenState extends State<AudioImageSetupScreen> {
  AudioImageNature _nature = AudioImageNature.contentAnalysis;
  AudioImageContext _context = AudioImageContext.digitalMedia;
  late final Set<ExpectedAudioImageEvidence> _expectedEvidences =
      _defaultEvidencesFor(_nature).toSet();

  final _bo = TextEditingController();
  final _protocol = TextEditingController();
  final _municipality = TextEditingController(text: 'Macapa');
  final _street = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _bo.dispose();
    _protocol.dispose();
    _municipality.dispose();
    _street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio e Imagem')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 14),
            _NatureCard(
              selected: _nature,
              onSelected: (nature) {
                setState(() {
                  _nature = nature;
                  _context = _defaultContextFor(nature);
                  _expectedEvidences
                    ..clear()
                    ..addAll(_defaultEvidencesFor(nature));
                });
              },
            ),
            const SizedBox(height: 12),
            _ContextCard(
              selected: _context,
              onSelected: (context) => setState(() => _context = context),
            ),
            const SizedBox(height: 12),
            _EvidenceCard(
              selected: _expectedEvidences,
              onChanged: (evidence, selected) {
                setState(() {
                  if (selected) {
                    _expectedEvidences.add(evidence);
                  } else {
                    _expectedEvidences.remove(evidence);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _FocusCard(nature: _nature),
            const SizedBox(height: 16),
            _InitialCaseFields(
              bo: _bo,
              protocol: _protocol,
              municipality: _municipality,
              street: _street,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _creating ? null : _createOccurrence,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('Criar ocorrencia'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOccurrence() async {
    setState(() => _creating = true);
    final occurrence = await widget.repository.createOccurrence(
      CaseData(
        bo: _bo.text.trim(),
        protocol: _protocol.text.trim(),
        municipality: _municipality.text.trim().isEmpty
            ? 'Macapa'
            : _municipality.text.trim(),
        street: _street.text.trim(),
      ),
      metadata: ForensicCaseMetadata(
        type: ForensicCaseType.audioImage,
        audioImageNature: _nature,
        audioImageContext: _context,
        expectedAudioImageEvidences: _expectedEvidences.toList(),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Icon(Icons.perm_media_outlined, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao inicial de audio e imagem',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Naturezas e pontos de atencao alinhados ao POP federal de Audio e Imagem.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NatureCard extends StatelessWidget {
  const _NatureCard({required this.selected, required this.onSelected});

  final AudioImageNature selected;
  final ValueChanged<AudioImageNature> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Natureza do exame',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AudioImageNature.values.map((nature) {
                return ChoiceChip(
                  label: Text(nature.label),
                  selected: selected == nature,
                  onSelected: (_) => onSelected(nature),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.selected, required this.onSelected});

  final AudioImageContext selected;
  final ValueChanged<AudioImageContext> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AudioImageContext.values.map((context) {
                return ChoiceChip(
                  label: Text(context.label),
                  selected: selected == context,
                  onSelected: (_) => onSelected(context),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.selected, required this.onChanged});

  final Set<ExpectedAudioImageEvidence> selected;
  final void Function(ExpectedAudioImageEvidence evidence, bool selected)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elementos esperados',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpectedAudioImageEvidence.values.map((evidence) {
                return FilterChip(
                  label: Text(evidence.label),
                  selected: selected.contains(evidence),
                  onSelected: (value) => onChanged(evidence, value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.nature});

  final AudioImageNature nature;

  @override
  Widget build(BuildContext context) {
    final items = _focusItems(nature);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(nature), color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nature.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 17,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _focusItems(AudioImageNature nature) {
    return switch (nature) {
      AudioImageNature.contentAnalysis => const [
        'Definir arquivo, trecho, evento e referencia temporal',
        'Preservar original, calcular hashes e extrair quadros quando cabivel',
        'Registrar coerencia entre conteudo visualizado e quesitos',
      ],
      AudioImageNature.imageEnhancement => const [
        'Trabalhar sempre sobre copia preservando o material original',
        'Registrar filtros, ajustes e criterios empregados',
        'Hash do resultado melhorado e limitacoes tecnicas',
      ],
      AudioImageNature.imageRecognition => const [
        'Definir pessoa/objeto questionado e material padrao',
        'Avaliar adequabilidade, obstrucoes, foco e iluminacao',
        'Registrar grau de limitacao do reconhecimento',
      ],
      AudioImageNature.facialComparison => const [
        'Verificar face, pose, nitidez, resolucao e obstrucoes',
        'Separar imagem questionada e padrao de origem conhecida',
        'Preparar material para futura comparacao facial no Desktop',
      ],
      AudioImageNature.imageEditVerification => const [
        'Preservar arquivo original e analisar metadados/estrutura',
        'Buscar inconformidades perceptuais, temporais ou de codificacao',
        'Registrar conclusao em termos de suporte e limitacao',
      ],
      AudioImageNature.speakerComparison => const [
        'Separar audio questionado e padrao vocal',
        'Avaliar ruido, compressao, sobreposicao e duracao util',
        'Registrar consentimento e condicoes da coleta do padrao',
      ],
      AudioImageNature.cctvPreservation => const [
        'Identificar DVR/NVR, cameras, periodo e risco de sobrescrita',
        'Extrair preferencialmente em formato nativo',
        'Hash dos dados extraidos e registro do responsavel/testemunha',
      ],
      AudioImageNature.statureEstimation => const [
        'Verificar topo/base e referencias metricas na cena',
        'Registrar tecnica, frames usados e intervalo estimado',
        'Tratar estatura como estimativa complementar',
      ],
      AudioImageNature.other => const [
        'Preservar midias, arquivos, hashes e cadeia de custodia',
        'Delimitar quesitos, material questionado e limitacoes',
        'Organizar o dossie para analise futura no Desktop',
      ],
    };
  }

  IconData _icon(AudioImageNature nature) {
    return switch (nature) {
      AudioImageNature.contentAnalysis => Icons.visibility_outlined,
      AudioImageNature.imageEnhancement => Icons.tune_outlined,
      AudioImageNature.imageRecognition => Icons.center_focus_strong_outlined,
      AudioImageNature.facialComparison => Icons.face_outlined,
      AudioImageNature.imageEditVerification => Icons.verified_outlined,
      AudioImageNature.speakerComparison => Icons.record_voice_over_outlined,
      AudioImageNature.cctvPreservation => Icons.videocam_outlined,
      AudioImageNature.statureEstimation => Icons.straighten_outlined,
      AudioImageNature.other => Icons.fact_check_outlined,
    };
  }
}

class _InitialCaseFields extends StatelessWidget {
  const _InitialCaseFields({
    required this.bo,
    required this.protocol,
    required this.municipality,
    required this.street,
  });

  final TextEditingController bo;
  final TextEditingController protocol;
  final TextEditingController municipality;
  final TextEditingController street;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dados iniciais',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bo,
          decoration: const InputDecoration(
            labelText: 'BO',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: protocol,
          decoration: const InputDecoration(
            labelText: 'Protocolo',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: municipality,
          decoration: const InputDecoration(
            labelText: 'Municipio',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: street,
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Logradouro / referencia',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
      ],
    );
  }
}

AudioImageContext _defaultContextFor(AudioImageNature nature) {
  return switch (nature) {
    AudioImageNature.cctvPreservation => AudioImageContext.cctvSystem,
    AudioImageNature.speakerComparison => AudioImageContext.personSample,
    AudioImageNature.contentAnalysis => AudioImageContext.digitalMedia,
    AudioImageNature.imageEnhancement => AudioImageContext.digitalMedia,
    AudioImageNature.imageRecognition => AudioImageContext.digitalMedia,
    AudioImageNature.facialComparison => AudioImageContext.personSample,
    AudioImageNature.imageEditVerification => AudioImageContext.digitalMedia,
    AudioImageNature.statureEstimation => AudioImageContext.crimeScene,
    AudioImageNature.other => AudioImageContext.digitalMedia,
  };
}

List<ExpectedAudioImageEvidence> _defaultEvidencesFor(AudioImageNature nature) {
  return switch (nature) {
    AudioImageNature.contentAnalysis => const [
      ExpectedAudioImageEvidence.originalMedia,
      ExpectedAudioImageEvidence.multimediaFiles,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.frames,
      ExpectedAudioImageEvidence.metadata,
      ExpectedAudioImageEvidence.hashes,
    ],
    AudioImageNature.imageEnhancement => const [
      ExpectedAudioImageEvidence.originalMedia,
      ExpectedAudioImageEvidence.images,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.frames,
      ExpectedAudioImageEvidence.hashes,
    ],
    AudioImageNature.imageRecognition => const [
      ExpectedAudioImageEvidence.images,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.referenceMaterial,
      ExpectedAudioImageEvidence.frames,
    ],
    AudioImageNature.facialComparison => const [
      ExpectedAudioImageEvidence.facialImages,
      ExpectedAudioImageEvidence.referenceMaterial,
      ExpectedAudioImageEvidence.frames,
      ExpectedAudioImageEvidence.metadata,
    ],
    AudioImageNature.imageEditVerification => const [
      ExpectedAudioImageEvidence.originalMedia,
      ExpectedAudioImageEvidence.multimediaFiles,
      ExpectedAudioImageEvidence.metadata,
      ExpectedAudioImageEvidence.hashes,
    ],
    AudioImageNature.speakerComparison => const [
      ExpectedAudioImageEvidence.audioRecords,
      ExpectedAudioImageEvidence.vocalSample,
      ExpectedAudioImageEvidence.metadata,
      ExpectedAudioImageEvidence.hashes,
    ],
    AudioImageNature.cctvPreservation => const [
      ExpectedAudioImageEvidence.cctvDvrNvr,
      ExpectedAudioImageEvidence.cameraSystem,
      ExpectedAudioImageEvidence.storageDevice,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.accessCredentials,
      ExpectedAudioImageEvidence.hashes,
    ],
    AudioImageNature.statureEstimation => const [
      ExpectedAudioImageEvidence.images,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.frames,
      ExpectedAudioImageEvidence.referenceMaterial,
    ],
    AudioImageNature.other => const [
      ExpectedAudioImageEvidence.originalMedia,
      ExpectedAudioImageEvidence.multimediaFiles,
      ExpectedAudioImageEvidence.metadata,
      ExpectedAudioImageEvidence.hashes,
    ],
  };
}
