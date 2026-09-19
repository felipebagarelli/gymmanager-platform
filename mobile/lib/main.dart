import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // Sem retry automatico: erros aparecem na tela e o usuario decide tentar de novo.
    ProviderScope(retry: (retryCount, error) => null, child: const GymManagerApp()),
  );
}
