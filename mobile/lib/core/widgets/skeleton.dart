import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bloco cinza que marca o lugar de um conteúdo enquanto ele carrega.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 14});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Esqueleto de uma tela de lista: alguns cartões cinzas empilhados.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.heights = const [240, 90, 90, 72, 72]});

  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          for (final h in heights) Padding(padding: const EdgeInsets.only(bottom: 12), child: SkeletonBox(height: h, radius: 20)),
        ],
      ),
    );
  }
}
