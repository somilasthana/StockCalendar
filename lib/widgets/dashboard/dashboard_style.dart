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

const howOftenBorder = Color(0xFF5B5BD6);
const priceOnBuyBorder = Color(0xFF0E948C);
const pricePathBorder = Color(0xFF0F9D8A);
const againstAverageBorder = Color(0xFFE4537C);

Color chartSurface(Brightness brightness, ColorScheme scheme) {
  return brightness == Brightness.light ? Colors.white : scheme.surface;
}

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
      ? const Color(0xFF7EE0D6)
      : const Color(0xFF0E948C);
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.caption,
    required this.borderColor,
    required this.child,
  });

  final String title;
  final String caption;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Card(
      elevation: 0,
      color: chartSurface(brightness, scheme),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
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
