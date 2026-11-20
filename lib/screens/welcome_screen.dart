import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../theme/calendar_theme.dart';
import 'calendar_screen.dart';

const _ink = Color(0xFF1B2330);
const _muted = Color(0xFF5C6770);
const _teal = Color(0xFF2BBFB8);
const _tealDeep = Color(0xFF149A94);
const _mint = Color(0xFFF3F7F6);
const _panel = Color(0xFFE7F4F1);
const _navy = Color(0xFF1A2332);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const _MintScaffold(
      child: _IntroPage(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _MintScaffold(
      child: _ToolsPage(
        onOpenCalendar: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/calendar'),
              builder: (_) => const CalendarScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _MintScaffold extends StatelessWidget {
  const _MintScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildLightTheme(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _mint,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _mint,
          body: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _MintPatternPainter())),
              SafeArea(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandMark(),
                const SizedBox(height: 32),
                const Center(child: _Badge(label: 'Smarter investor, less work')),
                const SizedBox(height: 28),
                const Text(
                  'Automate every\ninvestment journey,',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const Text(
                  'effortlessly.',
                  style: TextStyle(
                    color: _teal,
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'From the first touch to long-term investing, Stock Calendar helps build a transparent and effective journey. Once configured, it can run on autopilot.',
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.45),
                ),
                const Spacer(),
                const SizedBox(height: 28),
                _PillButton(
                  label: "Let's Get Started",
                  filled: true,
                  onPressed: () => context.read<AuthController>().completeIntro(),
                ),
                const SizedBox(height: 12),
                const _PillButton(
                  label: 'Watch demo',
                  filled: false,
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _noop() {}

class _ToolsPage extends StatelessWidget {
  const _ToolsPage({required this.onOpenCalendar});

  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(),
          const SizedBox(height: 28),
          const Text(
            'Happy Investing,',
            style: TextStyle(
              color: _ink,
              fontSize: 32,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const Text(
            'Intelligent Investing.',
            style: TextStyle(
              color: _teal,
              fontSize: 32,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'We build intelligent tools for our users so that they can invest with comfort and ease without any fear.',
            style: TextStyle(color: _muted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 22),
          _ToolCard(
            icon: Icons.calendar_month,
            title: 'Personal Stock Calendar',
            detail: 'Plan buys on market days, track them, and open your calendar.',
            onTap: onOpenCalendar,
          ),
          _ToolCard(
            icon: Icons.hourglass_empty,
            title: 'Coming Soon',
            detail: 'Another tool is on the way.',
            muted: true,
            onTap: () => _onTheWay(context),
          ),
          _ToolCard(
            icon: Icons.widgets_outlined,
            title: 'Coming Soon',
            detail: 'A further tool will land here later.',
            muted: true,
            onTap: () => _onTheWay(context),
          ),
        ],
      ),
    );
  }

  void _onTheWay(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('On the way.')));
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x140F1C28), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: _tealDeep, size: 20),
            SizedBox(width: 8),
            Text(
              'Stock Calendar AI',
              style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4ECEA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 15, color: _tealDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFE4E7EB)),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x24101C28), blurRadius: 28, offset: Offset(0, 14)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: muted ? const Color(0xFFEEF3F2) : _panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: muted ? const Color(0xFF8E9AA0) : _tealDeep,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: const TextStyle(color: _muted, fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MintPatternPainter extends CustomPainter {
  const _MintPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD5E4E0);
    final shapes = <RRect>[
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-50, 70, 170, 210),
        const Radius.circular(36),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 90, 24, 180, 150),
        const Radius.circular(32),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 140, size.height * 0.55, 200, 240),
        const Radius.circular(40),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-30, size.height * 0.72, 120, 160),
        const Radius.circular(28),
      ),
    ];
    for (final shape in shapes) {
      canvas.drawRRect(shape, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
