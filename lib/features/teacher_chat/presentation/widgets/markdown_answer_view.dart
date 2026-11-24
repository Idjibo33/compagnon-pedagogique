import 'package:compagnon_pedagogique/core/utils/emoji_sanitizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Rendu d'une réponse du modèle local avec support du streaming réactif.
///
/// Le Markdown est affiché (plus de balises visibles), les formules LaTeX sont
/// rendues avec flutter_math_fork et les titres de section reçoivent une icône
/// vectorielle. L'application ne produit aucun emoji.
class MarkdownAnswerView extends StatelessWidget {
  const MarkdownAnswerView({
    super.key,
    required this.content,
    this.isStreaming = false,
    this.highContrast = false,
  });

  /// Texte brut renvoyé par le modèle.
  final String content;

  /// Indique si les tokens sont activement en train d'être diffusés.
  final bool isStreaming;

  /// Active le contraste maximal pour le mode plein soleil (WCAG AAA).
  final bool highContrast;

  TextStyle get _bodyStyle => TextStyle(
        color: highContrast ? Colors.black : const Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal,
        height: 1.5,
      );

  TextStyle get _headingStyle => TextStyle(
        color: highContrast ? Colors.black : const Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        height: 1.4,
      );

  Color get _primaryColor =>
      highContrast ? const Color(0xFF0D47A1) : const Color(0xFF1A6FEE);

  @override
  Widget build(BuildContext context) {
    // Filet de sécurité : même si le modèle désobéit, aucun emoji n'est affiché.
    final cleanContent = stripEmojis(content);

    // En mode streaming, isoler/fermer les balises incomplètes pour éliminer les sauts visuels
    final processedContent =
        isStreaming ? _isolateIncompleteMarkup(cleanContent) : cleanContent;

    final title = _documentTitle(processedContent);
    final intro = _introText(processedContent);
    final sections = _parseSections(processedContent);
    final styleSheet = MarkdownStyleSheet(
      p: _bodyStyle,
      strong: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
      em: _bodyStyle.copyWith(fontStyle: FontStyle.italic),
      listBullet: _bodyStyle,
      code: _bodyStyle.copyWith(fontFamily: 'monospace'),
      blockquote: _bodyStyle,
      h1: _headingStyle.copyWith(fontSize: 17),
      h2: _headingStyle,
      h3: _headingStyle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (sections.isEmpty)
          _buildRichBody(
            _removeTitle(processedContent),
            styleSheet,
            showCursor: isStreaming,
          )
        else ...[
          if (intro != null && intro.isNotEmpty) ...[
            _buildRichBody(
              intro,
              styleSheet,
              showCursor: false,
            ),
            const SizedBox(height: 12),
          ],
          for (int i = 0; i < sections.length; i++) ...[
            Row(
              children: [
                Icon(sections[i].icon, size: 17, color: _primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(sections[i].title, style: _headingStyle),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildRichBody(
              sections[i].body,
              styleSheet,
              showCursor: isStreaming && (i == sections.length - 1),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  /// Extrait le texte d'introduction situé avant la première section ##
  static String? _introText(String markdown) {
    final buffer = StringBuffer();
    for (final line in markdown.split('\n')) {
      if (RegExp(r'^##\s+').hasMatch(line.trim())) {
        break;
      }
      if (!RegExp(r'^#\s+').hasMatch(line.trim())) {
        buffer.writeln(line);
      }
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Retire la ligne de titre principal (# Titre) pour éviter un doublon d'affichage
  static String _removeTitle(String markdown) {
    return markdown
        .split('\n')
        .where((line) => !RegExp(r'^#\s+').hasMatch(line.trim()))
        .join('\n')
        .trim();
  }

  /// Isole et équilibre les balises Markdown et LaTeX incomplètes pendant le streaming
  static String _isolateIncompleteMarkup(String text) {
    if (text.isEmpty) return text;
    var sanitized = text;

    // 1. Fermer temporairement un bloc LaTeX incomplet en cours de frappe
    final doubleDollarCount = RegExp(r'\$\$').allMatches(sanitized).length;
    if (doubleDollarCount.isOdd) {
      sanitized = '$sanitized\$\$';
    } else {
      final singleDollarCount =
          RegExp(r'(?<!\$)\$(?!\$)').allMatches(sanitized).length;
      if (singleDollarCount.isOdd) {
        sanitized = '$sanitized\$';
      }
    }

    // 2. Fermer temporairement les blocs de code triples backticks et inline
    final codeBlockCount = RegExp(r'```').allMatches(sanitized).length;
    if (codeBlockCount.isOdd) {
      sanitized = '$sanitized\n```';
    } else {
      final inlineCodeCount =
          RegExp(r'(?<!`)`(?!`)').allMatches(sanitized).length;
      if (inlineCodeCount.isOdd) {
        sanitized = '$sanitized`';
      }
    }

    // 3. Fermer temporairement le gras Markdown incomplet (**)
    final boldCount = RegExp(r'\*\*').allMatches(sanitized).length;
    if (boldCount.isOdd) {
      sanitized = '$sanitized**';
    }

    // 4. Éviter d'afficher un titre ## incomplet vide
    if (sanitized.endsWith('##') || sanitized.endsWith('## ')) {
      sanitized = sanitized.replaceAll(RegExp(r'##\s*$'), '');
    }

    return sanitized;
  }

  /// Titre principal écrit sous la forme `# Titre` par le modèle.
  String? _documentTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final match = RegExp(r'^#\s+(.+)$').firstMatch(line.trim());
      if (match != null) return match.group(1)!.trim();
    }
    return null;
  }

  List<_AnswerSection> _parseSections(String markdown) {
    final sections = <_AnswerSection>[];
    final buffer = StringBuffer();
    String? title;
    IconData icon = Icons.article_outlined;

    void flush() {
      if (title == null) {
        buffer.clear();
        return;
      }
      sections.add(
        _AnswerSection(
          title: title,
          icon: icon,
          body: buffer.toString().trim(),
        ),
      );
      buffer.clear();
    }

    for (final line in markdown.split('\n')) {
      final match = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
      if (match != null) {
        flush();
        title = match.group(1)!.trim();
        icon = _iconFor(title);
      } else if (!RegExp(r'^#\s+').hasMatch(line.trim())) {
        buffer.writeln(line);
      }
    }
    flush();
    return sections;
  }

  /// Icône associée à un titre de section, sans emoji décoratif.
  IconData _iconFor(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('objectif')) return Icons.flag_outlined;
    if (normalized.contains('déroulement') ||
        normalized.contains('deroulement') ||
        normalized.contains('étape')) {
      return Icons.list_alt_outlined;
    }
    if (normalized.contains('exercice')) return Icons.edit_note_outlined;
    if (normalized.contains('corrigé') || normalized.contains('corrige')) {
      return Icons.check_circle_outline;
    }
    if (normalized.contains('matériel') || normalized.contains('materiel')) {
      return Icons.construction_outlined;
    }
    if (normalized.contains('durée') || normalized.contains('duree')) {
      return Icons.schedule_outlined;
    }
    if (normalized.contains('source') || normalized.contains('référence')) {
      return Icons.menu_book_outlined;
    }
    return Icons.article_outlined;
  }

  /// Découpe le texte pour rendre les formules `$...$` et `$$...$$`.
  static final RegExp _formulaPattern =
      RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]+?\$');

  Widget _buildRichBody(
    String body,
    MarkdownStyleSheet styleSheet, {
    bool showCursor = false,
  }) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      if (showCursor) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _BreathingCursor(color: _primaryColor),
        );
      }
      return const SizedBox.shrink();
    }

    final matches = _formulaPattern.allMatches(trimmedBody).toList();
    final children = <Widget>[];

    if (matches.isEmpty) {
      children.add(
        MarkdownBody(
          data: trimmedBody,
          selectable: true,
          styleSheet: styleSheet,
        ),
      );
    } else {
      var cursor = 0;
      for (final match in matches) {
        final before = trimmedBody.substring(cursor, match.start);
        if (before.trim().isNotEmpty) {
          children.add(
            MarkdownBody(
              data: before.trim(),
              selectable: true,
              styleSheet: styleSheet,
            ),
          );
        }
        children.add(_formula(match.group(0)!));
        cursor = match.end;
      }
      final after = trimmedBody.substring(cursor);
      if (after.trim().isNotEmpty) {
        children.add(
          MarkdownBody(
            data: after.trim(),
            selectable: true,
            styleSheet: styleSheet,
          ),
        );
      }
    }

    if (showCursor) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _BreathingCursor(color: _primaryColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _formula(String part) {
    final display = part.startsWith(r'$$') && part.endsWith(r'$$');
    final expression = display
        ? part.substring(2, part.length - 2)
        : part.substring(1, part.length - 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Math.tex(
        expression.trim(),
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: _bodyStyle,
        onErrorFallback: (error) => Text(expression.trim(), style: _bodyStyle),
      ),
    );
  }
}

/// Curseur respiratoire doux teinté en Bleu Royal (#1A6FEE) ou haute visibilité
class _BreathingCursor extends StatefulWidget {
  final Color color;
  const _BreathingCursor({this.color = const Color(0xFF1A6FEE)});

  @override
  State<_BreathingCursor> createState() => _BreathingCursorState();
}

class _BreathingCursorState extends State<_BreathingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Text(
        '▋',
        style: TextStyle(
          color: widget.color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Section titre + icône extraite de la réponse du modèle.
class _AnswerSection {
  const _AnswerSection({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;
}
