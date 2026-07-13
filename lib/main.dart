import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';
import 'package:runanywhere_mlx/runanywhere_mlx.dart';
import 'package:runanywhere_onnx/runanywhere_onnx.dart';
import 'package:runanywhere_qhexrt/runanywhere_qhexrt.dart';

import 'services/model_service.dart';
import 'theme/app_theme.dart';
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the RunAnywhere SDK
  await RunAnywhere.initialize();

  // Register backends
  LlamaCpp.register();
  await Onnx.register();

  // Apple MLX (physical iOS devices only; safe no-op elsewhere).
  await MLX.register();

  // QHexRT Qualcomm Hexagon NPU (Android/Snapdragon only; safe no-op
  // elsewhere — register() rejects internally on unsupported parts).
  if (QHexRT.isAvailable) {
    await QHexRT.register();
  }

  // Register models
  await ModelService.registerDefaultModels();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ModelService(),
      child: const RunAnywhereStarterApp(),
    ),
  );
}

class RunAnywhereStarterApp extends StatelessWidget {
  const RunAnywhereStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunAnywhere Starter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeView(),
    );
  }
}
