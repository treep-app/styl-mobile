import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Figma 3-step booking progress: Book Appointment → Payment → Finished.
class BookingStepper extends StatelessWidget {
  const BookingStepper({super.key, required this.currentStep});

  /// 0 = book, 1 = payment, 2 = finished
  final int currentStep;

  static const _labels = ['Book Appointment', 'Payment', 'Finished'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _StepDot(
                    index: i,
                    currentStep: currentStep,
                  ),
                  if (i < 2)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: currentStep > i
                            ? AppColors.brandAccent
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          currentStep == i ? FontWeight.w700 : FontWeight.w400,
                      color: currentStep == i
                          ? Colors.black
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentStep;
    final isDone = index < currentStep;

    if (isActive || isDone) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.brandAccent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }

    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFFD0D0D0),
        shape: BoxShape.circle,
      ),
    );
  }
}
