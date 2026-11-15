import 'package:flutter/material.dart';

const dashboardPalette = [
  Color(0xFF5B5BD6),
  Color(0xFFE4537C),
  Color(0xFFFF8A3D),
  Color(0xFF1AA6A6),
  Color(0xFFF0B429),
  Color(0xFF7C4DFF),
  Color(0xFF2F9E44),
  Color(0xFF3D8BFF),
  Color(0xFFD6336C),
  Color(0xFF0CA678),
];

Color dashboardColor(int index) => dashboardPalette[index % dashboardPalette.length];

Color gainColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF3DDC84)
      : const Color(0xFF1B8A3E);
}

Color lossColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFFF6B6B)
      : const Color(0xFFD64545);
}

Color histogramColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF8AB4F8)
      : const Color(0xFF1A73E8);
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class ChartWaiting extends StatelessWidget {
  const ChartWaiting({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
