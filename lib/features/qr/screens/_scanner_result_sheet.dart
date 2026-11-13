import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom sheet shown after a QR scan attempt — success or failure.
class ScannerResultSheet extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String? time;
  final VoidCallback onDone;
  final VoidCallback? onScanAgain;

  const ScannerResultSheet({
    super.key,
    required this.success,
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    this.time,
    required this.onDone,
    this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Status icon.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 16),

          // Title.
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: success ? AppColors.textPrimary : AppColors.error,
            ),
          ),
          const SizedBox(height: 8),

          // Message.
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          // Time display if available.
          if (time != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Time: $time',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Primary action button.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    success ? AppColors.success : AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                success ? 'Go to Dashboard' : 'OK',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // "Scan Again" only for non-fatal failures.
          if (onScanAgain != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onScanAgain,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Scan Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
