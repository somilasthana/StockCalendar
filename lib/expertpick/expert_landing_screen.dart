import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/calendar_controller.dart';
import '../theme/calendar_theme.dart';
import 'expert_calendar_screen.dart';
import 'expert_import.dart';
import 'expert_side_menu.dart';

const _ink = Color(0xFF1B2330);
const _muted = Color(0xFF5C6770);
const _teal = Color(0xFF2BBFB8);
const _tealDeep = Color(0xFF149A94);
const _mint = Color(0xFFF3F7F6);

/// The screen behind the first expert-scrip dialog.
class ExpertLandingScreen extends StatelessWidget {
  const ExpertLandingScreen({super.key, required this.imports});

  final ExpertImportStore imports;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
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
          drawer: ExpertSideMenu(
            email: auth.email ?? '',
            onImport: () => refreshExpertScrip(
              context,
              imports: imports,
              calendar: context.read<CalendarController>(),
            ),
            onExpertPick: () => reopenExpertOpinion(
              context,
              imports: imports,
              calendar: context.read<CalendarController>(),
            ),
            onShowCalendar: () => presentExpertCalendar(
              context,
              imports: imports,
              fromCalendar: false,
            ),
            onPersonal: () => showOnTheWay(context),
            onReset: () => resetExpertCalendar(context),
          ),
          body: const Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _LandingPainter())),
              SafeArea(child: _LandingBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: _ink),
          ),
        ),
        const _BrandMark(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Headline(),
                  const SizedBox(height: 18),
                  const Text(
                    'This tool assists in viewing what the market suggests, and in backtesting those claims by spreading the recommended stocks across a calendar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This will not only help you gain knowledge about the market and individual stocks, but also evaluate the recommendations on backtested data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  const _Motif(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Welcome to',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        Text(
          'Portfolio Exploration',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _teal,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        Text(
          'by Experts',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class _Motif extends StatelessWidget {
  const _Motif();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ShapeCard(
          color: Color(0xFFE7F4F1),
          child: Icon(Icons.calendar_month, color: _tealDeep, size: 28),
        ),
        SizedBox(width: 14),
        _Donut(),
        SizedBox(width: 14),
        _ShapeCard(
          color: Colors.white,
          child: Icon(Icons.insights, color: _tealDeep, size: 28),
        ),
      ],
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F1C28),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x140F1C28),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const CustomPaint(painter: _DonutPainter()),
    );
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
            BoxShadow(
              color: Color(0x140F1C28),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: _tealDeep, size: 20),
            SizedBox(width: 8),
            Text(
              'Stock Calendar AI',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingPainter extends CustomPainter {
  const _LandingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    fill.color = const Color(0x332BBFB8);
    canvas.drawCircle(Offset(size.width + 10, 80), 120, fill);
    fill.color = const Color(0x22149A94);
    canvas.drawCircle(Offset(-20, size.height * 0.72), 90, fill);
    fill.color = const Color(0x66FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 130, size.height * 0.58, 160, 180),
        const Radius.circular(40),
      ),
      fill,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD5E4E0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-40, 120, 150, 190),
        const Radius.circular(36),
      ),
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.28),
      46,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: 24,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt;
    paint.color = const Color(0xFF2BBFB8);
    canvas.drawArc(rect, -1.2, 2.4, false, paint);
    paint.color = const Color(0xFF7C6AE8);
    canvas.drawArc(rect, 1.3, 1.5, false, paint);
    paint.color = const Color(0xFFF2C14E);
    canvas.drawArc(rect, 2.9, 1.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
