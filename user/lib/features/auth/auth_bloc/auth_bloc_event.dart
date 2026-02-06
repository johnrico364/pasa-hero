import 'package:flutter/widgets.dart';

@immutable
abstract class AuthBlocEvent {}

/// Initial Event with load data
class LoadAuthBlocEvent extends AuthBlocEvent {
  LoadAuthBlocEvent({required this.id});
  final String? id;
  
  @override
  String toString() => 'LoadAuthBlocEvent';
}

class AddAuthBlocEvent extends AuthBlocEvent {
  @override
  String toString() => 'AddAuthBlocEvent';
}

class ErrorYouAwesomeEvent extends AuthBlocEvent {
  static const String _name = 'ErrorYouAwesomeEvent';

  @override
  String toString() => _name;
}

class ClearAuthBlocEvent extends AuthBlocEvent {
  @override
  String toString() => 'ClearAuthBlocEvent';
}
