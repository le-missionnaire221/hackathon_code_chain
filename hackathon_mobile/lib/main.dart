import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  runApp(const CodeChainFintechApp());
}

class CodeChainFintechApp extends StatelessWidget {
  const CodeChainFintechApp({super.key});

  /// Largeur max de l'app : sur Chrome / tablette, l'app s'affiche
  /// comme un téléphone centré au lieu de s'étirer sur tout l'écran.
  static const double maxAppWidth = 480;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayChain Dakar - Lightning POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final width = math.min(mq.size.width, maxAppWidth);

        return ColoredBox(
          color: AppColors.sapphire,
          child: Center(
            child: SizedBox(
              width: width,
              child: MediaQuery(
                // Protection globale anti-overflow :
                // 1) la taille de police système est bornée (0.85x → 1.15x)
                // 2) la largeur déclarée correspond à la largeur réelle de l'app
                data: mq.copyWith(
                  size: Size(width, mq.size.height),
                  textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}

/// Permet de scroller / tirer pour rafraîchir à la souris sur Chrome
/// (indispensable pour la démo sur ordinateur).
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
