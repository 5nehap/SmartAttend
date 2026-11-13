import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../bloc/qr_bloc.dart';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-generate a QR when the screen opens.
    context.read<QRBloc>().add(const QRGenerateRequested());
  }

  @override
  void dispose() {
    // Cancel timer when screen closes by resetting to Initial.
    // The BLoC's close() method handles timer cancellation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Generate Attendance QR'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Cancel timer when navigating back.
            final state = context.read<QRBloc>().state;
            if (state is QRGenerated) {
              context
                  .read<QRBloc>()
                  .add(QRExpireRequested(sessionId: state.session.sessionId));
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: BlocConsumer<QRBloc, QRState>(
        listener: (context, state) {
          if (state is QRExpired) {
            AppSnackbar.showInfo(context, 'QR code has expired.');
          } else if (state is QRError) {
            AppSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _AdminHeader(),
                const SizedBox(height: 20),
                _QRCard(state: state),
                const SizedBox(height: 20),
                _CountdownSection(state: state),
                const SizedBox(height: 24),
                _ActionButtons(state: state),
                const SizedBox(height: 20),
                _SecurityNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Admin Header ─────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryIndigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance QR Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'QR expires in 60 seconds. Share with employees to scan.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(190),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Display Card ──────────────────────────────────────────────────────

class _QRCard extends StatelessWidget {
  final QRState state;

  const _QRCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (state is QRGenerating)
            const SizedBox(
              height: 240,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryBlue),
                    SizedBox(height: 16),
                    Text(
                      'Generating QR Code...',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else if (state is QRGenerated) ...[
            _ActiveQRDisplay(state: state as QRGenerated),
          ] else if (state is QRExpired)
            _ExpiredDisplay()
          else
            _PlaceholderDisplay(),
        ],
      ),
    );
  }
}

class _ActiveQRDisplay extends StatelessWidget {
  final QRGenerated state;

  const _ActiveQRDisplay({required this.state});

  @override
  Widget build(BuildContext context) {
    // Visual urgency: turn red in last 15 seconds.
    final isUrgent = state.remainingSeconds <= 15;
    final borderColor =
        isUrgent ? AppColors.error : AppColors.primaryBlue;

    return Column(
      children: [
        // Session status badge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Session Active',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // QR Code image.
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2.5),
            borderRadius: BorderRadius.circular(16),
            color: isUrgent
                ? AppColors.error.withAlpha(10)
                : Colors.white,
          ),
          child: QrImageView(
            data: state.payload,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: isUrgent ? AppColors.error : AppColors.primaryBlue,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: isUrgent ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Session ID.
        Text(
          'Session: ${state.session.sessionId.substring(0, 20)}...',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ExpiredDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.timer_off_rounded,
              color: AppColors.error,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'QR Code Expired',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a new QR code for the next session.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_rounded, size: 80, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'Tap "Generate QR" to create an attendance session.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Countdown Section ────────────────────────────────────────────────────

class _CountdownSection extends StatelessWidget {
  final QRState state;

  const _CountdownSection({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is! QRGenerated) {
      return const SizedBox.shrink();
    }

    final generated = state as QRGenerated;
    final remaining = generated.remainingSeconds;
    final isUrgent = remaining <= 15;
    final progress = remaining / 60.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_rounded,
                color: isUrgent ? AppColors.error : AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Session Timer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isUrgent ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent ? AppColors.errorLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$remaining s',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isUrgent ? AppColors.error : AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isUrgent
                  ? AppColors.error.withAlpha(30)
                  : AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? AppColors.error : AppColors.primaryBlue,
              ),
            ),
          ),
          if (isUrgent) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 14),
                SizedBox(width: 4),
                Text(
                  'QR expires soon! Employees should scan now.',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final QRState state;

  const _ActionButtons({required this.state});

  @override
  Widget build(BuildContext context) {
    final isGenerating = state is QRGenerating;

    return AppButton(
      label: state is QRGenerated ? 'Generate New QR' : 'Generate QR Code',
      isLoading: isGenerating,
      icon: Icons.qr_code_rounded,
      onPressed: isGenerating
          ? null
          : () => context.read<QRBloc>().add(const QRGenerateRequested()),
    );
  }
}

// ─── Security Note ────────────────────────────────────────────────────────

class _SecurityNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠ LOCAL MOCK: QR validation runs locally for this assessment. '
              'In production, all QR session verification must be performed '
              'server-side by a trusted backend.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.brown.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
