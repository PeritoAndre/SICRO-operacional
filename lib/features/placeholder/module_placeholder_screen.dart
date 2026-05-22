import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.construction_outlined,
        title: '$title em estruturacao',
        message:
            'Este modulo ja esta reservado na arquitetura do v0.1. A proxima etapa e trocar esta tela por coleta real offline.',
      ),
    );
  }
}
