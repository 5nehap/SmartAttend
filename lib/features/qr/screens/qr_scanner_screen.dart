import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/bloc/attendance_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/qr_bloc.dart';
import '_scanner_result_sheet.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _torchOn = false;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_resultShown) {
      _cameraController.start();
    } else if (state == AppLifecycleState.paused) {
      _cameraController.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _resultShown) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    _isProcessing = true;
    _cameraController.stop();

    // Reset QRBloc to initial before dispatching new validation.
    context.read<QRBloc>().add(QRValidateRequested(rawPayload: raw));
  }

  void _toggleTorch() {
    _cameraController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _reset() {
    setState(() {
      _isProcessing = false;
      _resultShown = false;
    });
    // Reset the scanner state without generating a new QR (scanner role only).
    // Re-start camera.
    _cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Attendance QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Toggle flashlight',
          ),
        ],
      ),
      body: BlocListener<QRBloc, QRState>(
        listener: (context, qrState) {
          if (qrState is QRValidationSuccess) {
            _onQRValid(context, qrState.sessionId);
          } else if (qrState is QRExpired) {
            _showResultSheet(
              success: false,
              title: 'QR Code Expired',
              message: qrState.message,
              icon: Icons.timer_off_rounded,
              iconColor: AppColors.error,
            );
          } else if (qrState is QRError) {
            _showResultSheet(
              success: false,
              title: 'Invalid QR Code',
              message: qrState.message,
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.error,
            );
          }
        },
        child: Stack(
          children: [
            // ─── Camera Preview ────────────────────────────────────
            MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),

            // ─── Dark overlay with scanning frame ──────────────────
            _ScanOverlay(),

            // ─── Bottom instruction panel ──────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ScanInstructionPanel(
                isProcessing: _isProcessing,
              ),
            ),

            // ─── Loading indicator while validating ───────────────
            BlocBuilder<QRBloc, QRState>(
              builder: (context, state) {
                if (state is QRValidating) {
                  return const Center(
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: AppColors.primaryBlue),
                            SizedBox(height: 14),
                            Text('Validating QR code...',
                                style:
                                    TextStyle(color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Called after QR is valid — now mark attendance.
  void _onQRValid(BuildContext context, String sessionId) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      _showResultSheet(
        success: false,
        title: 'Session Error',
        message: 'You must be logged in to mark attendance.',
        icon: Icons.lock_outline_rounded,
        iconColor: AppColors.error,
      );
      return;
    }

    final employee = authState.employee;

    // Dispatch unified QR-based attendance event (auto check-in/check-out).
    context.read<AttendanceBloc>().add(
          AttendanceMarkFromQRRequested(
            employeeId: employee.id,
            employeeName: employee.name,
          ),
        );

    // Listen to AttendanceBloc for the result.
    _listenToAttendanceResult(context, sessionId);
  }

  void _listenToAttendanceResult(BuildContext context, String sessionId) {
    // Capture blocs before the async gap to satisfy use_build_context_synchronously.
    final attendanceBloc = context.read<AttendanceBloc>();
    final qrBloc = context.read<QRBloc>();

    late final StreamSubscription<AttendanceState> sub;
    sub = attendanceBloc.stream.listen((state) {
      if (!mounted) {
        sub.cancel();
        return;
      }

      if (state is AttendanceActionSuccess) {
        sub.cancel();
        // Invalidate QR session so it can't be reused.
        qrBloc.add(QRExpireRequested(sessionId: sessionId));
        _showResultSheet(
          success: true,
          title: state.isCheckIn ? 'Check-In Recorded! ✓' : 'Check-Out Recorded! ✓',
          message: state.message,
          icon: state.isCheckIn
              ? Icons.login_rounded
              : Icons.logout_rounded,
          iconColor: AppColors.success,
          time: state.updatedRecord?.checkInTime ??
              state.updatedRecord?.checkOutTime,
          shouldReturnToDashboard: true,
        );
      } else if (state is AttendanceError) {
        sub.cancel();
        // Determine if this is duplicate attendance.
        final isDuplicate =
            state.message.contains('already complete') ||
            state.message.contains('already checked out');
        _showResultSheet(
          success: false,
          title: isDuplicate ? 'Already Completed' : 'Attendance Error',
          message: state.message,
          icon: isDuplicate
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          iconColor: isDuplicate ? AppColors.warning : AppColors.error,
        );
      }
    });
  }

  void _showResultSheet({
    required bool success,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String? time,
    bool shouldReturnToDashboard = false,
  }) {
    if (!mounted || _resultShown) return;
    setState(() => _resultShown = true);

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ScannerResultSheet(
        success: success,
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        time: time,
        onDone: () {
          Navigator.of(context).pop(); // Close sheet
          if (shouldReturnToDashboard) {
            Navigator.of(context).pop(); // Return to dashboard
          } else {
            _reset();
          }
        },
        onScanAgain: shouldReturnToDashboard
            ? null
            : () {
                Navigator.of(context).pop();
                _reset();
              },
      ),
    );
  }
}

// ─── Scan Overlay ─────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: Container(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const scanSize = 240.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2 - 40;

    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanSize,
      height: scanSize,
    );

    // Semi-transparent dark overlay.
    final overlayPaint = Paint()..color = Colors.black.withAlpha(140);

    // Cut out the scan region.
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Blue border around scan area.
    final borderPaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      borderPaint,
    );

    // Corner decorations.
    const cornerLen = 24.0;
    const cornerWidth = 4.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // Top-left
      [
        Offset(scanRect.left, scanRect.top + cornerLen),
        Offset(scanRect.left, scanRect.top),
        Offset(scanRect.left + cornerLen, scanRect.top),
      ],
      // Top-right
      [
        Offset(scanRect.right - cornerLen, scanRect.top),
        Offset(scanRect.right, scanRect.top),
        Offset(scanRect.right, scanRect.top + cornerLen),
      ],
      // Bottom-left
      [
        Offset(scanRect.left, scanRect.bottom - cornerLen),
        Offset(scanRect.left, scanRect.bottom),
        Offset(scanRect.left + cornerLen, scanRect.bottom),
      ],
      // Bottom-right
      [
        Offset(scanRect.right - cornerLen, scanRect.bottom),
        Offset(scanRect.right, scanRect.bottom),
        Offset(scanRect.right, scanRect.bottom - cornerLen),
      ],
    ];

    for (final corner in corners) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Instruction Panel ────────────────────────────────────────────────────

class _ScanInstructionPanel extends StatelessWidget {
  final bool isProcessing;

  const _ScanInstructionPanel({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProcessing
                ? Icons.hourglass_top_rounded
                : Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            isProcessing
                ? 'Processing...'
                : 'Point camera at the QR code to scan',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Make sure QR code is well lit and within the frame',
            style: TextStyle(
              color: Colors.white.withAlpha(160),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
