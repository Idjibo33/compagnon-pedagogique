import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/local_rag_repository_impl.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Features - Model Manager
  sl.registerLazySingleton<ModelManagerRepository>(
    () => ModelManagerRepositoryImpl(),
  );

  sl.registerFactory(
    () => ModelManagerCubit(repository: sl<ModelManagerRepository>()),
  );

  // Features - RAG Engine (Formatteur de contexte & Référentiel vectoriel local)
  sl.registerLazySingleton<RagContextFormatter>(
    () => const RagContextFormatter(),
  );

  sl.registerLazySingleton<RagRepository>(
    () => LocalRagRepositoryImpl(formatter: sl<RagContextFormatter>()),
  );

  // Features - Teacher Chat (Pont Edge AI <-> flutter_ai_toolkit)
  sl.registerLazySingleton<EdgeAiLlmProvider>(
    () => EdgeAiLlmProvider(
      ragRepository: sl<RagRepository>(),
      ragContextFormatter: sl<RagContextFormatter>(),
      modelRepository: sl<ModelManagerRepository>(),
    ),
  );

  // Pré-initialisation de la base vectorielle locale des programmes scolaires
  try {
    await sl<RagRepository>().initialize();
  } catch (e) {
    // Sera re-tenté lors de la première requête si le bundle n'est pas encore prêt
  }
}

Future<void> resetDependencies() async {
  await sl.reset();
}
