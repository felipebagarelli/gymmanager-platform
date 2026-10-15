import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/trainer/messages/presentation/trainer_conversation_page.dart';
import '../../features/trainer/presentation/trainer_home_page.dart';
import '../../features/trainer/students/presentation/student_detail_page.dart';
import '../../features/trainer/students/presentation/student_form_page.dart';
import '../../features/sessions/presentation/completion_page.dart';
import '../../features/sessions/presentation/execute_workout_page.dart';
import '../../features/workouts/presentation/workout_detail_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (previous, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final user = auth.value;
      if (user == null) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/';
      // cada papel só navega pelas próprias telas
      if (user is TrainerUser && location.startsWith('/workouts')) return '/';
      if (user is StudentUser && location.startsWith('/trainer')) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/',
        // o mesmo app atende os dois papéis: o usuário logado define o modo
        builder: (context, state) => ref.read(authControllerProvider).value is TrainerUser
            ? const TrainerHomePage()
            : const HomePage(),
      ),
      GoRoute(
        path: '/workouts/:id',
        builder: (context, state) =>
            WorkoutDetailPage(workoutId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'run',
            builder: (context, state) =>
                ExecuteWorkoutPage(workoutId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'done',
            builder: (context, state) =>
                CompletionPage(workoutId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      // modo personal
      GoRoute(
        path: '/trainer/messages/:id',
        builder: (context, state) => TrainerConversationPage(conversationId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/trainer/students/new', builder: (context, state) => const StudentFormPage()),
      GoRoute(
        path: '/trainer/students/:id',
        builder: (context, state) => StudentDetailPage(studentId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => StudentFormPage(studentId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );
});
