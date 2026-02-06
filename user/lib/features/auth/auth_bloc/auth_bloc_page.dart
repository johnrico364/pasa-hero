import 'package:flutter/material.dart';
import 'auth_bloc_bloc.dart';
import 'auth_bloc_event.dart';
import 'auth_bloc_screen.dart';
import 'auth_bloc_provider.dart';


class AuthBlocPage extends StatefulWidget {
  const AuthBlocPage({
    required this.bloc,
    super.key
    });
  static const String routeName = '/authBloc';
  
  final AuthBlocBloc? bloc;

  @override
  State<AuthBlocPage> createState() => _AuthBlocPageState();
}

class _AuthBlocPageState extends State<AuthBlocPage> {

  AuthBlocBloc? _bloc;
  AuthBlocBloc get bloc {
    // get it by DI in real code.
    _bloc ??= widget.bloc ?? AuthBlocBloc(provider: AuthBlocProvider());
    return _bloc!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('AuthBloc'),
         actions: [
          IconButton(
            icon: const Icon(Icons.error),
            onPressed: () {
              bloc.add(ErrorYouAwesomeEvent());
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              bloc.add(AddAuthBlocEvent());
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              bloc.add(ClearAuthBlocEvent());
            },
          ),
        ],
      ),
      body: AuthBlocScreen(bloc: bloc),
    );
  }
}
