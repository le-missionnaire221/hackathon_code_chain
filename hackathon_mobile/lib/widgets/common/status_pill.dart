import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum PillTone { success, warning, neutral, error, info, whatsapp }

/// Petite pastille de statut. Le texte est toujours sur une seule ligne
/// avec ellipsis : elle ne peut pas provoquer d'overflow.
class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool showDot;
  final bool dense;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.info,
    this.icon,
    this.showDot = false,
    this.dense = false,
  });

  /// Traduit le statut renvoyé par le backend en libellé + couleur.
  static (String, PillTone) fromTransactionStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('libéré') || s.contains('libere') || s.contains('released') || s.contains('livré') || s.contains('livre')) {
      return ('Livré', PillTone.success);
    }
    if (s.contains('séquestré') || s.contains('sequestre') || s.contains('locked') || s.contains('argent gardé') || s.contains('gardé')) {
      return ('Argent gardé', PillTone.warning);
    }
    if (s.contains('confirm') || s.contains('paid') || s.contains('payé') || s.contains('paye')) {
      return ('Confirmé', PillTone.success);
    }
    if (s.contains('expir')) {
      return ('Expiré', PillTone.neutral);
    }
    return ('En attente', PillTone.warning);
  }

  (Color, Color) get _colors {
    switch (tone) {
      case PillTone.success:
        return (AppColors.successSoft, AppColors.successDark);
      case PillTone.warning:
        return (AppColors.amberLight, AppColors.amberDark);
      case PillTone.neutral:
        return (AppColors.surfaceMuted, AppColors.textSecondary);
      case PillTone.error:
        return (AppColors.errorLight, AppColors.error);
      case PillTone.info:
        return (AppColors.chipBackground, AppColors.primary);
      case PillTone.whatsapp:
        return (AppColors.whatsappSoft, AppColors.whatsappDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    final fontSize = dense ? 10.5 : 11.5;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: fg),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
