import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/generation_state_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le libellé de consultation des programmes officiels',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationStateIndicator(
            phase: GenerationPhase.retrievingCurriculum,
          ),
        ),
      ),
    );

    expect(
      find.text('Consultation des programmes officiels...'),
      findsOneWidget,
    );

    // Vérifier les caractéristiques visuelles (radius 16px, fond bleu pastel #E8F1FD, bordure #BFDBFE)
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFE8F1FD));
    expect(decoration.borderRadius, BorderRadius.circular(16));
    expect(decoration.border?.top.color, const Color(0xFFBFDBFE));
  });

  testWidgets(
      'affiche le libellé de structuration didactique pour loadingModel',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationStateIndicator(
            phase: GenerationPhase.loadingModel,
          ),
        ),
      ),
    );

    expect(
      find.text('Structuration didactique...'),
      findsOneWidget,
    );
  });

  testWidgets('affiche un libellé personnalisé si fourni', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationStateIndicator(
            phase: GenerationPhase.idle,
            customLabel: 'Chargement personnalisé...',
          ),
        ),
      ),
    );

    expect(find.text('Chargement personnalisé...'), findsOneWidget);
  });

  testWidgets(
      'prend en compte le mode plein soleil (highContrast) avec bordure et fond contrastés',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationStateIndicator(
            phase: GenerationPhase.retrievingCurriculum,
            highContrast: true,
          ),
        ),
      ),
    );

    expect(
      find.text('Consultation des programmes officiels...'),
      findsOneWidget,
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.border?.top.color, Colors.black);
  });
}
