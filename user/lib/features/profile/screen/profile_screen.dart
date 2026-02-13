import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/auth_bloc/auth_bloc_bloc.dart';
import '../../auth/auth_bloc/auth_bloc_provider.dart';
import '../../auth/auth_bloc/auth_bloc_event.dart';
import '../../auth/auth_bloc/auth_bloc_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../splashscreen/splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Create a bloc provider for the profile screen
    return BlocProvider(
      create: (context) => AuthBlocBloc(
        provider: AuthBlocProvider(
          authService: AuthService(),
        ),
      )..add(CheckAuthStateEvent()), // Check current auth state
      child: BlocConsumer<AuthBlocBloc, AuthBlocState>(
        listener: (context, state) {
          // When user is logged out, navigate to splash screen
          if (!state.isAuthenticated && !state.isLoading && state.user == null) {
            // Navigate to splash screen and clear navigation stack
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  ),
                  (route) => false,
                );
              }
            });
          }
          
          // Show error if logout fails
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error.toString().replaceAll('Exception: ', ''),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Section
                  if (state.user != null) ...[
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF1E3A8A),
                          child: Text(
                            state.user!.displayName?.substring(0, 1).toUpperCase() ?? 
                            state.user!.email?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          state.user!.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          state.user!.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Logout Button
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      trailing: state.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                      onTap: state.isLoading
                          ? null
                          : () {
                              // Show confirmation dialog
                              showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text(
                                      'Are you sure you want to logout?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          // Close dialog first
                                          Navigator.of(dialogContext).pop();
                                          
                                          try {
                                            // Sign out directly from Firebase Auth
                                            final authService = AuthService();
                                            await authService.signOut();
                                            
                                            // Use root navigator to navigate to splash screen
                                            // AuthWrapper will also detect the auth state change,
                                            // but we navigate immediately to ensure responsiveness
                                            if (context.mounted) {
                                              // Get the root navigator context
                                              final rootNavigator = Navigator.of(context, rootNavigator: true);
                                              rootNavigator.pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (context) => const SplashScreen(),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          } catch (e) {
                                            // Show error if logout fails
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Logout failed: ${e.toString()}'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Logout'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
