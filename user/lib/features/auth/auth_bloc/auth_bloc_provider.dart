import 'auth_bloc_view_model.dart';

class AuthBlocProvider {
  Future<List<AuthBlocItem>> fetchAsync(String? id) async {
    // Mock implementation - replace with actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [
      AuthBlocItem(name: 'Item 1'),
      AuthBlocItem(name: 'Item 2'),
      AuthBlocItem(name: 'Item 3'),
    ];
  }

  Future<List<AuthBlocItem>> addMore(List<AuthBlocItem>? existingItems) async {
    // Mock implementation - replace with actual API call
    await Future.delayed(const Duration(seconds: 1));
    final items = existingItems ?? <AuthBlocItem>[];
    final newItems = List<AuthBlocItem>.from(items);
    newItems.add(AuthBlocItem(name: 'New Item ${newItems.length + 1}'));
    return newItems;
  }
}
