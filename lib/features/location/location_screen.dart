import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/location_capture_service.dart';
import '../../domain/models/location_record.dart';
import '../../shared/widgets/empty_state.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({
    required this.repository,
    required this.occurrenceId,
    LocationCaptureService? captureService,
    super.key,
  }) : captureService = captureService ?? const LocationCaptureService();

  final OccurrenceRepository repository;
  final String occurrenceId;
  final LocationCaptureService captureService;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  StreamSubscription<LocationRecord>? _subscription;
  LocationRecord? _liveLocation;
  LocationRecord? _bestLocation;
  bool _starting = false;
  bool _listening = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAcquisition());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        if (occurrence == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Ocorrencia nao encontrada',
              message: 'Nao foi possivel acessar a localizacao deste dossie.',
            ),
          );
        }

        final savedLocation = occurrence.location;
        final currentQuality = LocationPrecisionQuality.fromAccuracy(
          _liveLocation?.accuracyMeters,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('GPS pericial')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AcquisitionHeader(
                  listening: _listening,
                  starting: _starting,
                  quality: currentQuality,
                  error: _error,
                ),
                const SizedBox(height: 12),
                _ReadingPanel(
                  title: 'Leitura atual',
                  icon: Icons.sensors_outlined,
                  location: _liveLocation,
                  emptyText: 'Aguardando primeira leitura do GPS...',
                ),
                const SizedBox(height: 12),
                _ReadingPanel(
                  title: 'Melhor leitura desta sessao',
                  icon: Icons.verified_outlined,
                  location: _bestLocation,
                  emptyText: 'A melhor precisao aparecera durante a aquisicao.',
                ),
                const SizedBox(height: 12),
                _ReadingPanel(
                  title: 'Localizacao salva no dossie',
                  icon: Icons.save_alt_outlined,
                  location: savedLocation.hasCoordinates ? savedLocation : null,
                  emptyText: 'Nenhuma coordenada salva nesta ocorrencia.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _bestLocation == null || _saving
                      ? null
                      : _saveBest,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Salvar melhor leitura'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _starting ? null : _startAcquisition,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    _listening
                        ? 'Reiniciar aquisicao GPS'
                        : 'Iniciar aquisicao GPS',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openLocationSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Abrir configuracoes de localizacao'),
                ),
                const SizedBox(height: 20),
                const _GuidanceCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startAcquisition() async {
    if (_starting) {
      return;
    }

    await _subscription?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _starting = true;
      _listening = false;
      _error = null;
      _liveLocation = null;
      _bestLocation = null;
    });

    try {
      await widget.captureService.ensureReady();
      final stream = widget.captureService.watchLocation();
      _subscription = stream.listen(
        _handleLocation,
        onError: (Object error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'Falha na aquisicao GPS: $error';
            _listening = false;
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _starting = false;
        _listening = true;
      });
    } on LocationCaptureException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _starting = false;
        _listening = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _starting = false;
        _listening = false;
        _error = 'Falha ao iniciar aquisicao GPS: $error';
      });
    }
  }

  void _handleLocation(LocationRecord location) {
    final currentBest = _bestLocation;
    setState(() {
      _liveLocation = location;
      if (currentBest == null || _isBetter(location, currentBest)) {
        _bestLocation = location;
      }
    });
  }

  bool _isBetter(LocationRecord candidate, LocationRecord currentBest) {
    final candidateAccuracy = candidate.accuracyMeters;
    final bestAccuracy = currentBest.accuracyMeters;
    if (candidateAccuracy == null) {
      return false;
    }
    if (bestAccuracy == null) {
      return true;
    }
    return candidateAccuracy < bestAccuracy;
  }

  Future<void> _saveBest() async {
    final chosen = _bestLocation;
    if (chosen == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.updateLocation(widget.occurrenceId, chosen);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS salvo: ${chosen.coordinateLabel} (${chosen.accuracyLabel}).',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    await widget.captureService.openLocationSettings();
  }
}

class _AcquisitionHeader extends StatelessWidget {
  const _AcquisitionHeader({
    required this.listening,
    required this.starting,
    required this.quality,
    required this.error,
  });

  final bool listening;
  final bool starting;
  final LocationPrecisionQuality quality;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(quality);
    final title = error != null
        ? 'Aquisicao interrompida'
        : starting
        ? 'Preparando GPS'
        : listening
        ? 'Aquisicao em andamento'
        : 'Aquisicao parada';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error != null ? AppColors.danger : color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error != null
                    ? Icons.error_outline
                    : listening
                    ? Icons.gps_fixed
                    : Icons.gps_not_fixed,
                color: error != null ? AppColors.danger : color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _PrecisionBadge(quality: quality),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            error ??
                'Aguarde a precisao melhorar e salve manualmente a melhor leitura.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({
    required this.title,
    required this.icon,
    required this.location,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final LocationRecord? location;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final record = location;
    final quality = LocationPrecisionQuality.fromAccuracy(
      record?.accuracyMeters,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _PrecisionBadge(quality: quality),
            ],
          ),
          const SizedBox(height: 14),
          if (record == null)
            Text(
              emptyText,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            _InfoRow(
              label: 'Latitude',
              value: record.latitude!.toStringAsFixed(7),
            ),
            _InfoRow(
              label: 'Longitude',
              value: record.longitude!.toStringAsFixed(7),
            ),
            _InfoRow(label: 'Precisao', value: record.accuracyLabel),
            _InfoRow(label: 'Fonte', value: record.source.toUpperCase()),
            _InfoRow(label: 'Horario', value: _dateLabel(record.capturedAt)),
          ],
        ],
      ),
    );
  }
}

class _PrecisionBadge extends StatelessWidget {
  const _PrecisionBadge({required this.quality});

  final LocationPrecisionQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(quality);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        quality.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uso em campo', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Permaneça alguns segundos no ponto de interesse. O app acompanha a precisao em tempo real e guarda a melhor leitura da sessao para salvamento manual.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

Color _qualityColor(LocationPrecisionQuality quality) {
  return switch (quality) {
    LocationPrecisionQuality.excellent => AppColors.success,
    LocationPrecisionQuality.acceptable => AppColors.gold,
    LocationPrecisionQuality.poor => AppColors.danger,
    LocationPrecisionQuality.unknown => AppColors.textSecondary,
  };
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return 'Nao capturado';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute:$second';
}
