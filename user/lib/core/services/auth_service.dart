import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Lazy initialization of GoogleSignIn to avoid errors if clientId is not set
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      // On web, clientId is read from <meta name="google-signin-client_id"> tag in index.html
      // On mobile, this is not needed
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update user display name
      await credential.user?.updateDisplayName('$firstName $lastName');

      // Save additional user data to Firestore
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in with Google (for login - checks if user exists in database)
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        throw Exception('Google Sign-In was cancelled.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if user exists in Firestore
      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // User doesn't exist in database - sign them out and throw error
          await _auth.signOut();
          await googleSignIn.signOut();
          throw Exception(
            'No account found. Please sign up first to create an account.',
          );
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('No account found')) {
        rethrow;
      }
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Sign up with Google (for registration - creates user in database)
  Future<UserCredential> signUpWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        throw Exception('Google Sign-Up was cancelled.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if user already exists in Firestore
      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          // User already exists - this is fine, just return the credential
          return userCredential;
        }

        // User doesn't exist - create user record in Firestore
        final displayName = userCredential.user!.displayName ?? '';
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        final lastName = nameParts.length > 1 
            ? nameParts.sublist(1).join(' ') 
            : '';

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'firstName': firstName.isNotEmpty ? firstName : 'User',
          'lastName': lastName.isNotEmpty ? lastName : '',
          'email': userCredential.user!.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'signUpMethod': 'google',
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        rethrow;
      }
      throw Exception('Google Sign-Up failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await googleSignIn.signOut(); // Also sign out from Google
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Handle Firebase Auth exceptions and return user-friendly messages
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'email-already-in-use':
        return Exception('An account already exists for that email.');
      case 'user-not-found':
        return Exception('No user found for that email.');
      case 'wrong-password':
        return Exception('Wrong password provided.');
      case 'invalid-email':
        return Exception('The email address is invalid.');
      case 'user-disabled':
        return Exception('This user account has been disabled.');
      case 'too-many-requests':
        return Exception('Too many requests. Please try again later.');
      case 'operation-not-allowed':
        return Exception('This operation is not allowed.');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}
