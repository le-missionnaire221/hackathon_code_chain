import 'package:flutter/material.dart';

class AppColors {
  // Couleurs principales Fintech / Neobank
  static const Color primary = Color(0xFF0052FF);       // Bleu Royal Neobank
  static const Color primaryDark = Color(0xFF003BB5);   // Bleu Profond
  static const Color sapphire = Color(0xFF0A2540);      // Saphir Nuit
  static const Color secondary = Color(0xFF00D2FF);     // Bleu Électrique
  static const Color lightningGold = Color(0xFFFFD166); // Or Éclair Lightning
  static const Color amber = Color(0xFFF59E0B);         // Ambre En attente
  static const Color amberDark = Color(0xFFD97706);

  // Statuts & Accents
  static const Color success = Color(0xFF10B981);       // Vert Émeraude
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFEF4444);         // Rouge Erreur
  static const Color errorLight = Color(0xFFFEE2E2);

  // Surfaces & Fonds (Thème Blanc & Bleu)
  static const Color background = Color(0xFFF8FAFC);    // Blanc cassé / Slate 50
  static const Color card = Colors.white;
  static const Color chipBackground = Color(0xFFEEF4FF);
  static const Color border = Color(0xFFE2E8F0);        // Slate 200

  // Textes & Typographie
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400

  // Dégradés Neobank
  static const LinearGradient walletGradient = LinearGradient(
    colors: [primary, primaryDark, sapphire],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarGradient = LinearGradient(
    colors: [primary, sapphire],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
