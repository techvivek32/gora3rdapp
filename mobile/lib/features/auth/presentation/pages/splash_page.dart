import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        } else if (state is AuthUnauthenticated) {
          context.go('/welcome');
        }
      },
      child: const Scaffold(
        body: SizedBox.expand(
          child: Image(
            image: AssetImage('assets/images/loding_screen.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
