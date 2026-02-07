import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_bloc_bloc.dart';
import 'auth_bloc_event.dart';
import 'auth_bloc_state.dart';

class AuthBlocScreen extends StatefulWidget {
  const AuthBlocScreen({
    required this.bloc,
    super.key,
  });

  @protected
  final AuthBlocBloc bloc;

  @override
  State<AuthBlocScreen> createState() {
    return AuthBlocScreenState();
  }
}

class AuthBlocScreenState extends State<AuthBlocScreen> {
  @override
  void initState() {
    super.initState();
    // Check auth state on init
    if (widget.bloc.state.user == null && !widget.bloc.state.isLoading) {
      _checkAuthState();
    }
  }

  @override
  void dispose() {
    // dispose bloc if you use subscriptions in bloc
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBlocBloc, AuthBlocState>(
      bloc: widget.bloc,
      builder: (
        BuildContext context,
        AuthBlocState currentState,
      ) {
        // declaration of bloc states
        return currentState.when(
          onLoading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          onUnauthenticated: () => _Empty(),
          onAuthenticated: (user) => _AuthenticatedView(user: user),
          onError: (e) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.toString()),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkAuthState,
                  child: const Text('Retry'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _checkAuthState() {
    widget.bloc.add(CheckAuthStateEvent());
  }
}

class _AuthenticatedView extends StatelessWidget {
  final user;

  const _AuthenticatedView({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Authenticated',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Email: ${user.email ?? 'N/A'}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'UID: ${user.uid}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.person_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Not Authenticated',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please log in to continue',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
