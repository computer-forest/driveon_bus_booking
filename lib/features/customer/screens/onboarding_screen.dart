import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import 'login_screen.dart';

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.directions_bus_filled_rounded,
    title: 'Hire the whole bus',
    body: 'No seats to pick — you book the entire vehicle for your trip window.',
  ),
  _Slide(
    icon: Icons.bolt_rounded,
    title: 'Live availability, instantly held',
    body: 'The moment you pick a bus, it is held so nobody else can take it while we confirm.',
  ),
  _Slide(
    icon: Icons.support_agent_rounded,
    title: 'A person confirms every detail',
    body: 'Our team calls to confirm the cost and driver — no automated pricing, no surprises.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index == _slides.length - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: AppRadius.heroRadius,
                          ),
                          child: Icon(slide.icon, size: 44, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Text(slide.title, textAlign: TextAlign.center, style: textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: PrimaryButton(
                label: _index == _slides.length - 1 ? 'Get started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
