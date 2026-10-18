import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/account/application/account_providers.dart';
import '../../features/ai_workout/presentation/ai_workout_page.dart';
import '../../features/account/presentation/guardian_pending_page.dart';
import '../../features/account/presentation/register_page.dart';
import '../../features/account/presentation/reset_password_page.dart';
import '../../features/account/presentation/verify_email_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/onboarding/application/onboarding_providers.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/trainer/messages/presentation/trainer_conversation_page.dart';
import '../../features/trainer/presentation/trainer_home_page.dart';
import '../../features/trainer/workouts/presentation/exercise_library_page.dart';
import '../../features/trainer/workouts/presentation/workout_editor_page.dart';
import '../../features/trainer/students/presentation/student_detail_page.dart';
import '../../features/trainer/students/presentation/student_form_page.dart';
import '../../features/trainer/students/presentation/student_progress_page.dart';
import '../../features/sessions/presentation/completion_page.dart';
import '../../features/sessions/presentation/execute_workout_page.dart';
import '../../features/workouts/presentation/workout_detail_page.dart';

const _accountPages = {'/register', '/verify-email', '/forgot-password', '/guardian-pending'};

/// E-mail e senha passam entre as telas da conta em memória (nunca na URL).
AccountFlowArgs _argsOf(GoRouterState state) =>
    state.extra is AccountFlowArgs ? state.extra! as AccountFlowArgs : const AccountFlowArgs();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (previous, next) => refresh.value++);
  ref.listen(needsOnboardingProvider, (previous, next) => refresh.value++);
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
      // cadastro, código e senha: abertos para quem ainda não entrou
      final publicPage = location == '/login' || _accountPages.contains(location);
      if (user == null) return publicPage ? null : '/login';
      if (publicPage || location == '/splash') return '/';
      // cada papel só navega pelas próprias telas
      if (user is TrainerUser && location.startsWith('/workouts')) return '/';
      if (user is StudentUser && location.startsWith('/trainer')) return '/';
      // aluno sem personal: antes de tudo, objetivo, rotina e triagem de saúde
      if (user is StudentUser && location != '/onboarding' && ref.read(needsOnboardingProvider)) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingPage()),
      GoRoute(path: '/ai-workout', builder: (context, state) => const AiWorkoutPage()),
      GoRoute(
        path: '/my-workouts/:id/edit',
        builder: (context, state) => WorkoutEditorPage(workoutId: int.parse(state.pathParameters['id']!), studentMode: true),
      ),
      GoRoute(path: '/verify-email', builder: (context, state) => VerifyEmailPage(args: _argsOf(state))),
      GoRoute(path: '/forgot-password', builder: (context, state) => ResetPasswordPage(args: _argsOf(state))),
      GoRoute(path: '/guardian-pending', builder: (context, state) => GuardianPendingPage(args: _argsOf(state))),
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
      GoRoute(path: '/trainer/exercises', builder: (context, state) => const ExerciseLibraryPage()),
      GoRoute(
        path: '/trainer/workouts/:id',
        builder: (context, state) => WorkoutEditorPage(workoutId: int.parse(state.pathParameters['id']!)),
      ),
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
          GoRoute(
            path: 'progress',
            builder: (context, state) => StudentProgressPage(
              studentId: int.parse(state.pathParameters['id']!),
              initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
    ],
  );
});
