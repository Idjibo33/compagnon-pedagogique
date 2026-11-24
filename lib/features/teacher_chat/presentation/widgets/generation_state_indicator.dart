import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:flutter/material.dart';

/// Indicateur d'état de génération compact et animé (TTFT - sans layout shift)
class GenerationStateIndicator extends StatefulWidget {
  final GenerationPhase phase;
  final String? customLabel;
  final bool highContrast;

  const GenerationStateIndicator({
    super.key,
    required this.phase,
    this.customLabel,
    this.highContrast = false,
  });

  @override
  State<GenerationStateIndicator> createState() =>
      _GenerationStateIndicatorState();
}

class _GenerationStateIndicatorState extends State<GenerationStateIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getLabel() {
    if (widget.customLabel != null) return widget.customLabel!;
    switch (widget.phase) {
      case GenerationPhase.retrievingCurriculum:
        return 'Consultation des programmes officiels...';
      case GenerationPhase.loadingModel:
        return 'Structuration didactique...';
      case GenerationPhase.clarifying:
        return 'Cadrage pédagogique...';
      case GenerationPhase.streamingTokens:
        return 'Rédaction en cours...';
      case GenerationPhase.completed:
        return 'Fiche prête';
      case GenerationPhase.error:
        return 'Erreur de génération';
      case GenerationPhase.idle:
        return 'Préparation de la fiche...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.highContrast ? Colors.white : const Color(0xFFE8F1FD);
    final borderColor =
        widget.highContrast ? Colors.black : const Color(0xFFBFDBFE);
    final primaryColor =
        widget.highContrast ? const Color(0xFF0D47A1) : const Color(0xFF1A6FEE);

    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: widget.highContrast ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getLabel(),
              style: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight:
                    widget.highContrast ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
