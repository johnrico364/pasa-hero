import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_bloc_bloc.dart';
import 'auth_bloc_event.dart';
import 'auth_bloc_state.dart';
import 'auth_bloc_view_model.dart';


class AuthBlocScreen extends StatefulWidget {
  const AuthBlocScreen({
    required this.bloc,
    super.key,
  }) ;

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
    // load data on init widget if bloc has not data
    if (!widget.bloc.state.hasData) {
      _load();
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
          onLoading: ()=>const CircularProgressIndicator(),
          onEmpty: (data) =>  _Empty(),
          onData: (data) =>  _BodyList(data: data),
          onError: (e) =>  Center(
            child: Column(
              children: [
                Text(e.toString()),
                TextButton(
                  onPressed: _load,
                  child: const Text('ReLoad'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _load() {
    widget.bloc.add(LoadAuthBlocEvent(id:'1'));
  }

}


class _BodyList extends StatefulWidget {
  const _BodyList({required this.data});

  final AuthBlocViewModel data;

  @override
  State<_BodyList> createState() => _BodyListState();
}

class _BodyListState extends State<_BodyList> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return CustomScrollView(
        // primary: true,
        slivers: [
          const SliverToBoxAdapter(child: Divider()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
          final item = widget.data.items![index];
          if (index == 0) {
            return Text('Header $index, id = ${item.name}');
          }
          return Text('Index = $index, id = ${item.name}');
        },
        childCount: widget.data.items!.length,
    ))]);
  }
}


class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('Empty'),
      ],
    );
  }
}