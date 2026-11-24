import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barre d'actions finales animée (Export PDF + Copier le texte avec feedback temporaire)
class FinalActionsBar extends StatefulWidget {
  final String content;
  final VoidCallback onExportPdf;
  final bool highContrast;

  const FinalActionsBar({
    super.key,
    required this.content,
    required this.onExportPdf,
    this.highContrast = false,
  });

  @override
  State<FinalActionsBar> createState() => _FinalActionsBarState();
}

class _FinalActionsBarState extends State<FinalActionsBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isCopied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.content));
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    setState(() {
      _isCopied = true;
    });

    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        widget.highContrast ? const Color(0xFF0D47A1) : const Color(0xFF1A6FEE);
    const successColor = Color(0xFF16A34A);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Bouton pilule "Exporter en PDF"
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryColor,
                elevation: 0,
                side: BorderSide(
                  color: primaryColor,
                  width: widget.highContrast ? 2.0 : 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              onPressed: widget.onExportPdf,
              icon: Icon(
                Icons.picture_as_pdf_rounded,
                size: 16,
                color: primaryColor,
              ),
              label: Text(
                'Exporter en PDF',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),

            // Bouton pilule "Copier le texte" avec coche verte temporaire
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isCopied ? const Color(0xFFDCFCE7) : Colors.white,
                foregroundColor: _isCopied ? successColor : primaryColor,
                elevation: 0,
                side: BorderSide(
                  color: _isCopied
                      ? successColor
                      : (widget.highContrast
                          ? Colors.black
                          : const Color(0xFFE2E8F0)),
                  width: widget.highContrast ? 2.0 : 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              onPressed: _handleCopy,
              icon: Icon(
                _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                size: 16,
                color: _isCopied
                    ? successColor
                    : (widget.highContrast
                        ? primaryColor
                        : const Color(0xFF64748B)),
              ),
              label: Text(
                _isCopied ? 'Copié !' : 'Copier le texte',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isCopied
                      ? successColor
                      : (widget.highContrast
                          ? primaryColor
                          : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
