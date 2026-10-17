import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Ligne "libellé ........ valeur" sûre : les deux côtés sont flexibles
/// et tronqués proprement, quelle que soit la longueur du texte.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;
  final VoidCallback? onCopy;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}
