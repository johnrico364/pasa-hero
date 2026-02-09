class AuthBlocViewModel {
  final List<AuthBlocItem>? items;

  AuthBlocViewModel({this.items});
}

class AuthBlocItem {
  final String name;

  AuthBlocItem({required this.name});
}
