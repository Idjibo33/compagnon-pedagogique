import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/di/injection_container.dart' as di;
import 'package:compagnon_pedagogique/core/di/injection_container.dart';
import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_state.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/screens/model_setup_screen.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/teacher_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de l'injection de dépendances et de la base RAG
  await di.initDependencies();

  // Vérifier si les modèles sont déjà installés sur l'appareil
  final modelRepo = sl<ModelManagerRepository>();
  final allReady = await modelRepo.areAllModelsReady();

  runApp(CompagnonPedagogiqueApp(initialModelsReady: allReady));
}

class CompagnonPedagogiqueApp extends StatelessWidget {
  final bool initialModelsReady;
  final EdgeAiLlmProvider? customLlmProvider;

  const CompagnonPedagogiqueApp({
    super.key,
    required this.initialModelsReady,
    this.customLlmProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ModelManagerCubit>(
          create: (_) => sl<ModelManagerCubit>()..checkStatus(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: BlocBuilder<ModelManagerCubit, ModelManagerState>(
          builder: (context, state) {
            if (state.areAllModelsReady || initialModelsReady) {
              return TeacherChatScreen(provider: customLlmProvider);
            }
            return const ModelSetupScreen();
          },
        ),
      ),
    );
  }
}
