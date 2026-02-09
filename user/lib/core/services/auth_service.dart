import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Lazy initialization of GoogleSignIn to avoid errors if clientId is not set
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      // IMPORTANT: For web, serverClientId MUST be null (reads from index.html meta tag)
      // Setting serverClientId for web causes assertion error
      // For Android/iOS: Use the Web OAuth Client ID as serverClientId
      serverClientId: kIsWeb 
          ? null 
          : _getWebClientId(), // Use Web client ID for mobile platforms only
      scopes: ['email', 'profile', 'openid'], // 'openid' scope is required for idToken
    );
    return _googleSignIn!;
  }

  // Get the Web OAuth Client ID from Firebase options
  // This is needed for Android/iOS Google Sign-In
  // IMPORTANT: Replace this with your actual Web OAuth Client ID from Firebase Console
  // Get it from: Firebase Console > Project Settings > Your apps > Web app > OAuth client ID
  String? _getWebClientId() {
    // Web OAuth Client ID from Firebase Console
    // This is required for Android/iOS Google Sign-In to work properly
    // The Web Client ID is used as serverClientId for mobile platforms
    const String? webClientId = '464857061623-ohoa4afqj73bka9l3mn4rv7mdrpe0ra0.apps.googleusercontent.com';
    
    return webClientId;
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

      // Update user display name and save to Firestore
      if (credential.user != null) {
        // Save additional user data to Firestore first
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Update user display name
        await credential.user!.updateDisplayName('$firstName $lastName');
        
        // Reload user to get updated display name
        await credential.user!.reload();
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
      GoogleSignInAccount? googleUser;
      
      // For web, skip signInSilently to avoid FedCM errors and warnings
      // signInSilently always fails for first-time users and creates noise
      // Go straight to signIn() which shows the popup
      if (kIsWeb) {
        try {
          googleUser = await googleSignIn.signIn();
        } catch (signInError) {
          // Handle popup_closed error as cancellation
          final errorStr = signInError.toString().toLowerCase();
          if (errorStr.contains('popup_closed') || 
              errorStr.contains('popup closed') ||
              errorStr.contains('cancelled')) {
            throw Exception('Google Sign-In was cancelled.');
          }
          // Handle CORS/COOP errors
          if (errorStr.contains('cross-origin') ||
              errorStr.contains('crossorigin') ||
              errorStr.contains('opener-policy') ||
              errorStr.contains('coop')) {
            throw Exception(
              'Google Sign-In failed due to browser security settings. '
              'Please check your browser settings or try a different browser.'
            );
          }
          // Handle other FedCM/unknown errors
          if (errorStr.contains('unknown_reason') ||
              errorStr.contains('networkerror') ||
              errorStr.contains('not signed in')) {
            throw Exception('Google Sign-In failed. Please try again.');
          }
          rethrow;
        };
      } else {
        // For mobile platforms, use regular signIn
        googleUser = await googleSignIn.signIn();
      }
      
      // VALIDATION STEP 1: Check if googleUser is valid
      if (googleUser == null) {
        print('❌ VALIDATION FAILED: googleUser is null - user cancelled sign-in');
        throw Exception('Google Sign-In was cancelled.');
      }
      
      print('✅ VALIDATION PASSED: googleUser is not null');
      print('📋 Google User Email: ${googleUser.email ?? "N/A"}');
      print('📋 Google User ID: ${googleUser.id ?? "N/A"}');
      print('📋 Google User Display Name: ${googleUser.displayName ?? "N/A"}');

      // Obtain the auth details from the request
      // CRITICAL: The People API 403 error happens AFTER token retrieval
      // The idToken is in the OAuth response, not from People API
      // We need to get the tokens even if People API fails
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔑 STEP 2: Requesting authentication tokens from Google...');
      print('═══════════════════════════════════════════════════════════');
      GoogleSignInAuthentication? googleAuth;
      
      try {
        print('⏳ Calling googleUser.authentication...');
        // Try to get authentication - this may throw due to People API 403
        // but the tokens should still be available in the response
        googleAuth = await googleUser.authentication;
        print('✅ SUCCESS: Authentication object retrieved');
        print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
        print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
        
        // DEBUG: Comprehensive inspection of authentication object
        print('');
        print('🔍 DEBUG: Detailed authentication object inspection:');
        print('   - accessToken is null: ${googleAuth.accessToken == null}');
        print('   - idToken is null: ${googleAuth.idToken == null}');
        if (googleAuth.accessToken != null) {
          print('   - accessToken length: ${googleAuth.accessToken!.length}');
          print('   - accessToken starts with: ${googleAuth.accessToken!.substring(0, 10)}...');
        }
        if (googleAuth.idToken != null) {
          print('   - idToken length: ${googleAuth.idToken!.length}');
          print('   - idToken starts with: ${googleAuth.idToken!.substring(0, 10)}...');
        } else {
          print('   - ⚠️ idToken is NULL - this is the problem!');
          print('   - The OAuth response may not include id_token');
          print('   - This could be due to OAuth flow configuration');
        }
      } catch (e) {
        print('');
        print('❌❌❌ ERROR CAUGHT IN AUTHENTICATION CALL ❌❌❌');
        print('═══════════════════════════════════════════════════════════');
        print('⚠️ Exception Type: ${e.runtimeType}');
        print('⚠️ Exception Message: $e');
        print('⚠️ Full Error: ${e.toString()}');
        print('═══════════════════════════════════════════════════════════');
        
        final errorStr = e.toString().toLowerCase();
        final errorMessage = e.toString();
        
        // Check if this is a People API error (403)
        // IMPORTANT: The tokens are retrieved BEFORE the People API call
        // So even if People API fails, the tokens should be available
        final isPeopleApiError = errorStr.contains('403') || 
            errorStr.contains('forbidden') ||
            errorStr.contains('people api') ||
            errorStr.contains('content-people.googleapis.com');
        
        // Also check for ClientException/PlatformException which might wrap People API errors
        final isClientException = errorStr.contains('clientexception') || 
            errorStr.contains('platformexception');
        
        if (isPeopleApiError || (isClientException && errorStr.contains('403'))) {
          print('');
          print('🔍 DIAGNOSIS: People API 403 Error Detected');
          print('═══════════════════════════════════════════════════════════');
          print('The error is: $errorMessage');
          print('This means People API is not enabled in Google Cloud Console.');
          print('═══════════════════════════════════════════════════════════');
          print('');
          print('💡 Attempting to retrieve tokens despite People API error...');
          print('   (Tokens should still be available from OAuth response)');
          
          // The error is from People API, not from token retrieval
          // Try to access authentication again - the tokens might be cached
          try {
            print('⏳ Retry attempt 1: Waiting 500ms then retrying...');
            await Future.delayed(const Duration(milliseconds: 500));
            googleAuth = await googleUser.authentication;
            print('✅ SUCCESS: Authentication retrieved after People API error');
            print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
            print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
          } catch (retryError) {
            print('⚠️ Retry attempt 1 FAILED: $retryError');
            // Try one more time with longer delay
            try {
              print('⏳ Retry attempt 2: Waiting 1500ms then retrying...');
              await Future.delayed(const Duration(milliseconds: 1500));
              googleAuth = await googleUser.authentication;
              print('✅ SUCCESS: Authentication retrieved on second retry');
              print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
              print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
            } catch (finalError) {
              print('');
              print('❌❌❌ ALL RETRY ATTEMPTS FAILED ❌❌❌');
              print('═══════════════════════════════════════════════════════════');
              print('People API is blocking token access.');
              print('The google_sign_in package cannot retrieve tokens because');
              print('People API is not enabled in your Google Cloud Console.');
              print('═══════════════════════════════════════════════════════════');
              print('');
              print('💡 SOLUTION: Enable People API in Google Cloud Console');
              print('   1. Go to https://console.cloud.google.com/');
              print('   2. Select project: pasahero-db');
              print('   3. Click "APIs & Services" → "Library"');
              print('   4. Search for "People API"');
              print('   5. Click "Google People API"');
              print('   6. Click the "Enable" button');
              print('   7. Wait 1-2 minutes for activation');
              print('   8. Try Google Sign-In again');
              print('');
              throw Exception(
                '🚫 CRITICAL: People API Not Enabled\n\n'
                'Google Sign-In cannot work because People API is not enabled.\n'
                'This is REQUIRED - there is no workaround.\n\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'STEP-BY-STEP FIX (Takes 2 minutes):\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                '1. Open: https://console.cloud.google.com/\n'
                '2. Select project: pasahero-db\n'
                '3. Click "APIs & Services" (left menu)\n'
                '4. Click "Library"\n'
                '5. Search: "People API"\n'
                '6. Click "Google People API"\n'
                '7. Click "ENABLE" button\n'
                '8. Wait 1-2 minutes\n'
                '9. Refresh this page and try again\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'Error: ${errorMessage.substring(0, errorMessage.length > 200 ? 200 : errorMessage.length)}...'
              );
            }
          }
        } else if (isClientException) {
          // ClientException might be wrapping a People API error
          print('');
          print('🔍 DIAGNOSIS: ClientException/PlatformException Detected');
          print('═══════════════════════════════════════════════════════════');
          print('This might be a wrapped People API error.');
          print('Attempting to retrieve tokens anyway...');
          print('═══════════════════════════════════════════════════════════');
          
          // Try retries even for ClientException - it might be People API related
          try {
            print('⏳ Retry attempt 1: Waiting 500ms then retrying...');
            await Future.delayed(const Duration(milliseconds: 500));
            googleAuth = await googleUser.authentication;
            print('✅ SUCCESS: Authentication retrieved after exception');
            print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
            print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
          } catch (retryError) {
            print('⚠️ Retry attempt 1 FAILED: $retryError');
            // Try one more time
            try {
              print('⏳ Retry attempt 2: Waiting 1500ms then retrying...');
              await Future.delayed(const Duration(milliseconds: 1500));
              googleAuth = await googleUser.authentication;
              print('✅ SUCCESS: Authentication retrieved on second retry');
              print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
              print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
            } catch (finalError) {
              print('');
              print('❌❌❌ ALL RETRY ATTEMPTS FAILED ❌❌❌');
              print('═══════════════════════════════════════════════════════════');
              print('The authentication call is failing.');
              print('This is likely due to People API not being enabled.');
              print('═══════════════════════════════════════════════════════════');
              throw Exception(
                '🚫 CRITICAL: People API Not Enabled\n\n'
                'Google Sign-In cannot work because People API is not enabled.\n'
                'This is REQUIRED - there is no workaround.\n\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'STEP-BY-STEP FIX (Takes 2 minutes):\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                '1. Open: https://console.cloud.google.com/\n'
                '2. Select project: pasahero-db\n'
                '3. Click "APIs & Services" (left menu)\n'
                '4. Click "Library"\n'
                '5. Search: "People API"\n'
                '6. Click "Google People API"\n'
                '7. Click "ENABLE" button\n'
                '8. Wait 1-2 minutes\n'
                '9. Refresh this page and try again\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'Error Type: ${e.runtimeType}\n'
                'Error: ${errorMessage.substring(0, errorMessage.length > 150 ? 150 : errorMessage.length)}...'
              );
            }
          }
        } else {
          // Different error - rethrow with more details
          print('');
          print('❌❌❌ UNEXPECTED ERROR (NOT People API) ❌❌❌');
          print('═══════════════════════════════════════════════════════════');
          print('Error Type: ${e.runtimeType}');
          print('Error Message: $errorMessage');
          print('═══════════════════════════════════════════════════════════');
          rethrow;
        }
      }

      // VALIDATION STEP 3: Ensure we have an idToken (required for Firebase Auth)
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔍 STEP 3: Validating authentication tokens...');
      print('═══════════════════════════════════════════════════════════');
      
      if (googleAuth == null) {
        print('❌ VALIDATION FAILED: googleAuth is null');
        throw Exception(
          '🚫 Google Sign-In Failed: Authentication object is null\n\n'
          'Unable to retrieve authentication tokens from Google.\n'
          'Please enable People API in Google Cloud Console.'
        );
      }
      
      print('✅ VALIDATION PASSED: googleAuth is not null');
      
      // WORKAROUND: On web, google_sign_in doesn't return idToken when serverClientId is null
      // Try to proceed with just accessToken - Firebase Auth might accept it
      if (googleAuth.idToken == null) {
        print('⚠️ WARNING: idToken is null');
        print('📋 Access Token: ${googleAuth.accessToken != null ? "Present" : "NULL"}');
        
        if (kIsWeb) {
          print('');
          print('🔍 WEB PLATFORM DETECTED');
          print('The google_sign_in package on web has a known limitation:');
          print('it does not return idToken when serverClientId is null.');
          print('Attempting to use accessToken only as a workaround...');
          print('');
          
          // Try to create credential with just accessToken
          // Firebase Auth might accept it on web
          try {
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              // idToken is null, but we'll try without it
            );
            
            print('⏳ Attempting Firebase sign-in with accessToken only...');
            final userCredential = await _auth.signInWithCredential(credential);
            
            print('✅ Firebase sign-in successful with accessToken only!');
            print('📋 User ID: ${userCredential.user?.uid}');
            
            // Check if user exists in Firestore
            if (userCredential.user != null) {
              print('🔍 Checking if user exists in Firestore...');
              final userDoc = await _firestore
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .get();

              if (!userDoc.exists) {
                print('❌ User not found in Firestore, signing out...');
                await _auth.signOut();
                await googleSignIn.signOut();
                throw Exception(
                  'No account found. Please sign up first to create an account.',
                );
              }
              print('✅ User found in Firestore');
            }

            print('✅ Google Sign-In completed successfully (using accessToken workaround)');
            return userCredential;
          } catch (e) {
            print('❌ Firebase sign-in failed with accessToken only: $e');
            print('');
            print('The accessToken-only approach did not work.');
            print('This confirms that Firebase Auth requires idToken.');
            print('');
            throw Exception(
              '🚫 Google Sign-In Failed: ID Token is Required\n\n'
              'The google_sign_in package on web cannot provide an idToken\n'
              'when serverClientId is null (setting it causes an assertion error).\n\n'
              'This is a known limitation of the google_sign_in package on web.\n\n'
              'SOLUTION: Use Firebase Auth directly for web Google Sign-In.\n'
              'The google_sign_in package works better on mobile platforms.'
            );
          }
        } else {
          // For mobile platforms, idToken should always be present
          throw Exception(
            '🚫 Google Sign-In Failed: ID Token is Missing\n\n'
            'The authentication object was retrieved but the ID token is null.\n'
            'This should not happen on mobile platforms.\n\n'
            'Please check your Google Sign-In configuration.'
          );
        }
      }
      
      if (googleAuth.accessToken == null) {
        print('❌ VALIDATION FAILED: accessToken is null');
        print('📋 ID Token: ${googleAuth.idToken != null ? "Present" : "NULL"}');
        throw Exception(
          '🚫 Google Sign-In Failed: Access Token is null\n\n'
          'The authentication object was retrieved but the access token is missing.\n'
          'Please try again or enable People API in Google Cloud Console.'
        );
      }
      
      print('✅ VALIDATION PASSED: Both tokens are present');
      print('📋 Access Token: ${googleAuth.accessToken!.substring(0, 30)}...');
      print('📋 ID Token: ${googleAuth.idToken!.substring(0, 30)}...');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('✅ Google authentication successful, signing in to Firebase...');

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      print('✅ Firebase sign-in successful, user ID: ${userCredential.user?.uid}');

      // Check if user exists in Firestore
      if (userCredential.user != null) {
        print('🔍 Checking if user exists in Firestore...');
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          print('❌ User not found in Firestore, signing out...');
          // User doesn't exist in database - sign them out and throw error
          await _auth.signOut();
          await googleSignIn.signOut();
          throw Exception(
            'No account found. Please sign up first to create an account.',
          );
        }
        print('✅ User found in Firestore');
      }

      print('✅ Google Sign-In completed successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('No account found') || 
          e.toString().contains('cancelled')) {
        rethrow;
      }
      // Handle popup_closed error
      if (e.toString().contains('popup_closed') || 
          e.toString().contains('popup closed')) {
        throw Exception('Google Sign-In was cancelled.');
      }
      // Handle CORS/COOP errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cross-origin') ||
          errorStr.contains('crossorigin') ||
          errorStr.contains('opener-policy') ||
          errorStr.contains('coop')) {
        throw Exception(
          'Google Sign-In failed due to browser security settings. '
          'Please check your browser settings or try a different browser.'
        );
      }
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Sign up with Google (for registration - creates user in database)
  Future<UserCredential> signUpWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      
      // For web, skip signInSilently to avoid FedCM errors and warnings
      // signInSilently always fails for first-time users and creates noise
      // Go straight to signIn() which shows the popup
      if (kIsWeb) {
        try {
          googleUser = await googleSignIn.signIn();
        } catch (signInError) {
          // Handle popup_closed error as cancellation
          final errorStr = signInError.toString().toLowerCase();
          if (errorStr.contains('popup_closed') || 
              errorStr.contains('popup closed') ||
              errorStr.contains('cancelled')) {
            throw Exception('Google Sign-Up was cancelled.');
          }
          // Handle CORS/COOP errors
          if (errorStr.contains('cross-origin') ||
              errorStr.contains('crossorigin') ||
              errorStr.contains('opener-policy') ||
              errorStr.contains('coop')) {
            throw Exception(
              'Google Sign-Up failed due to browser security settings. '
              'Please check your browser settings or try a different browser.'
            );
          }
          // Handle other FedCM/unknown errors
          if (errorStr.contains('unknown_reason') ||
              errorStr.contains('networkerror') ||
              errorStr.contains('not signed in')) {
            throw Exception('Google Sign-Up failed. Please try again.');
          }
          rethrow;
        }
      } else {
        // For mobile platforms, use regular signIn
        googleUser = await googleSignIn.signIn();
      }
      
      // VALIDATION STEP 1: Check if googleUser is valid
      if (googleUser == null) {
        print('❌ VALIDATION FAILED: googleUser is null - user cancelled sign-up');
        throw Exception('Google Sign-Up was cancelled.');
      }
      
      print('✅ VALIDATION PASSED: googleUser is not null');
      print('📋 Google User Email: ${googleUser.email ?? "N/A"}');
      print('📋 Google User ID: ${googleUser.id ?? "N/A"}');
      print('📋 Google User Display Name: ${googleUser.displayName ?? "N/A"}');

      // Obtain the auth details from the request
      // CRITICAL: The People API 403 error happens AFTER token retrieval
      // The idToken is in the OAuth response, not from People API
      // We need to get the tokens even if People API fails
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔑 STEP 2: Requesting authentication tokens from Google...');
      print('═══════════════════════════════════════════════════════════');
      GoogleSignInAuthentication? googleAuth;
      
      try {
        print('⏳ Calling googleUser.authentication...');
        // Try to get authentication - this may throw due to People API 403
        // but the tokens should still be available in the response
        googleAuth = await googleUser.authentication;
        print('✅ SUCCESS: Authentication object retrieved');
        print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
        print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
        
        // DEBUG: Comprehensive inspection of authentication object
        print('');
        print('🔍 DEBUG: Detailed authentication object inspection:');
        print('   - accessToken is null: ${googleAuth.accessToken == null}');
        print('   - idToken is null: ${googleAuth.idToken == null}');
        if (googleAuth.accessToken != null) {
          print('   - accessToken length: ${googleAuth.accessToken!.length}');
          print('   - accessToken starts with: ${googleAuth.accessToken!.substring(0, 10)}...');
        }
        if (googleAuth.idToken != null) {
          print('   - idToken length: ${googleAuth.idToken!.length}');
          print('   - idToken starts with: ${googleAuth.idToken!.substring(0, 10)}...');
        } else {
          print('   - ⚠️ idToken is NULL - this is the problem!');
          print('   - The OAuth response may not include id_token');
          print('   - This could be due to OAuth flow configuration');
        }
      } catch (e) {
        print('');
        print('❌❌❌ ERROR CAUGHT IN AUTHENTICATION CALL ❌❌❌');
        print('═══════════════════════════════════════════════════════════');
        print('⚠️ Exception Type: ${e.runtimeType}');
        print('⚠️ Exception Message: $e');
        print('⚠️ Full Error: ${e.toString()}');
        print('═══════════════════════════════════════════════════════════');
        
        final errorStr = e.toString().toLowerCase();
        final errorMessage = e.toString();
        
        // Check if this is a People API error (403)
        // IMPORTANT: The tokens are retrieved BEFORE the People API call
        // So even if People API fails, the tokens should be available
        final isPeopleApiError = errorStr.contains('403') || 
            errorStr.contains('forbidden') ||
            errorStr.contains('people api') ||
            errorStr.contains('content-people.googleapis.com');
        
        // Also check for ClientException/PlatformException which might wrap People API errors
        final isClientException = errorStr.contains('clientexception') || 
            errorStr.contains('platformexception');
        
        if (isPeopleApiError || (isClientException && errorStr.contains('403'))) {
          print('');
          print('🔍 DIAGNOSIS: People API 403 Error Detected');
          print('═══════════════════════════════════════════════════════════');
          print('The error is: $errorMessage');
          print('This means People API is not enabled in Google Cloud Console.');
          print('═══════════════════════════════════════════════════════════');
          print('');
          print('💡 Attempting to retrieve tokens despite People API error...');
          print('   (Tokens should still be available from OAuth response)');
          
          // The error is from People API, not from token retrieval
          // Try to access authentication again - the tokens might be cached
          try {
            print('⏳ Retry attempt 1: Waiting 500ms then retrying...');
            await Future.delayed(const Duration(milliseconds: 500));
            googleAuth = await googleUser.authentication;
            print('✅ SUCCESS: Authentication retrieved after People API error');
            print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
            print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
          } catch (retryError) {
            print('⚠️ Retry attempt 1 FAILED: $retryError');
            // Try one more time with longer delay
            try {
              print('⏳ Retry attempt 2: Waiting 1500ms then retrying...');
              await Future.delayed(const Duration(milliseconds: 1500));
              googleAuth = await googleUser.authentication;
              print('✅ SUCCESS: Authentication retrieved on second retry');
              print('📋 Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 30)}..." : "NULL"}');
              print('📋 ID Token: ${googleAuth.idToken != null ? "${googleAuth.idToken!.substring(0, 30)}..." : "NULL"}');
            } catch (finalError) {
              print('');
              print('❌❌❌ ALL RETRY ATTEMPTS FAILED ❌❌❌');
              print('═══════════════════════════════════════════════════════════');
              print('People API is blocking token access.');
              print('The google_sign_in package cannot retrieve tokens because');
              print('People API is not enabled in your Google Cloud Console.');
              print('═══════════════════════════════════════════════════════════');
              print('');
              print('💡 SOLUTION: Enable People API in Google Cloud Console');
              print('   1. Go to https://console.cloud.google.com/');
              print('   2. Select project: pasahero-db');
              print('   3. Click "APIs & Services" → "Library"');
              print('   4. Search for "People API"');
              print('   5. Click "Google People API"');
              print('   6. Click the "Enable" button');
              print('   7. Wait 1-2 minutes for activation');
              print('   8. Try Google Sign-Up again');
              print('');
              throw Exception(
                '🚫 Google Sign-Up Failed: People API Error\n\n'
                'The People API is not enabled in your Google Cloud Console.\n'
                'This is REQUIRED for Google Sign-In to work on web.\n\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'HOW TO FIX:\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                '1. Go to: https://console.cloud.google.com/\n'
                '2. Select project: pasahero-db\n'
                '3. Click "APIs & Services" → "Library"\n'
                '4. Search for "People API"\n'
                '5. Click "Google People API"\n'
                '6. Click the "Enable" button\n'
                '7. Wait 1-2 minutes\n'
                '8. Try signing up again\n'
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
                'Error Details: $errorMessage'
              );
            }
          }
        } else {
          // Different error - rethrow with more details
          print('');
          print('❌❌❌ UNEXPECTED ERROR (NOT People API) ❌❌❌');
          print('═══════════════════════════════════════════════════════════');
          print('Error Type: ${e.runtimeType}');
          print('Error Message: $errorMessage');
          print('═══════════════════════════════════════════════════════════');
          rethrow;
        }
      }

      // VALIDATION STEP 3: Ensure we have an idToken (required for Firebase Auth)
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔍 STEP 3: Validating authentication tokens...');
      print('═══════════════════════════════════════════════════════════');
      
      if (googleAuth == null) {
        print('❌ VALIDATION FAILED: googleAuth is null');
        throw Exception(
          '🚫 Google Sign-Up Failed: Authentication object is null\n\n'
          'Unable to retrieve authentication tokens from Google.\n'
          'Please enable People API in Google Cloud Console.'
        );
      }
      
      print('✅ VALIDATION PASSED: googleAuth is not null');
      
      // WORKAROUND: On web, google_sign_in doesn't return idToken when serverClientId is null
      // Try to proceed with just accessToken - Firebase Auth might accept it
      if (googleAuth.idToken == null) {
        print('⚠️ WARNING: idToken is null');
        print('📋 Access Token: ${googleAuth.accessToken != null ? "Present" : "NULL"}');
        
        if (kIsWeb) {
          print('');
          print('🔍 WEB PLATFORM DETECTED');
          print('The google_sign_in package on web has a known limitation:');
          print('it does not return idToken when serverClientId is null.');
          print('Attempting to use accessToken only as a workaround...');
          print('');
          
          // Try to create credential with just accessToken
          try {
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              // idToken is null, but we'll try without it
            );
            
            print('⏳ Attempting Firebase sign-in with accessToken only...');
            final userCredential = await _auth.signInWithCredential(credential);
            
            print('✅ Firebase sign-in successful with accessToken only!');
            print('📋 User ID: ${userCredential.user?.uid}');
            
            // Check if user already exists in Firestore
            if (userCredential.user != null) {
              print('🔍 Checking if user exists in Firestore...');
              final userDoc = await _firestore
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .get();

              if (userDoc.exists) {
                print('✅ User already exists in Firestore');
                return userCredential;
              }

              print('📝 Creating new user in Firestore...');
              // User doesn't exist - create user record in Firestore
              final displayName = userCredential.user!.displayName ?? '';
              final nameParts = displayName.split(' ');
              final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
              final lastName = nameParts.length > 1 
                  ? nameParts.sublist(1).join(' ') 
                  : '';

              try {
                final userData = {
                  'firstName': firstName.isNotEmpty ? firstName : 'User',
                  'lastName': lastName.isNotEmpty ? lastName : '',
                  'email': userCredential.user!.email ?? '',
                  'createdAt': FieldValue.serverTimestamp(),
                  'signUpMethod': 'google',
                };
                await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
                print('✅ User created successfully in Firestore');
              } catch (e) {
                print('❌ Error creating user in Firestore: $e');
                throw Exception('Failed to create user profile: $e');
              }
            }

            print('✅ Google Sign-Up completed successfully (using accessToken workaround)');
            return userCredential;
          } catch (e) {
            print('❌ Firebase sign-in failed with accessToken only: $e');
            throw Exception(
              '🚫 Google Sign-Up Failed: ID Token is Required\n\n'
              'The google_sign_in package on web cannot provide an idToken.\n'
              'This is a known limitation of the package on web.'
            );
          }
        } else {
          // For mobile platforms, idToken should always be present
          throw Exception(
            '🚫 Google Sign-Up Failed: ID Token is null\n\n'
            'The authentication object was retrieved but the ID token is missing.\n'
            'This should not happen on mobile platforms.\n\n'
            'Please check your Google Sign-In configuration.'
          );
        }
      }
      
      if (googleAuth.accessToken == null) {
        print('❌ VALIDATION FAILED: accessToken is null');
        print('📋 ID Token: ${googleAuth.idToken != null ? "Present" : "NULL"}');
        throw Exception(
          '🚫 Google Sign-Up Failed: Access Token is null\n\n'
          'The authentication object was retrieved but the access token is missing.\n'
          'Please try again or enable People API in Google Cloud Console.'
        );
      }
      
      print('✅ VALIDATION PASSED: Both tokens are present');
      print('📋 Access Token: ${googleAuth.accessToken!.substring(0, 30)}...');
      print('📋 ID Token: ${googleAuth.idToken!.substring(0, 30)}...');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('✅ Google authentication successful, signing in to Firebase...');

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      print('✅ Firebase sign-in successful, user ID: ${userCredential.user?.uid}');

      // Check if user already exists in Firestore
      if (userCredential.user != null) {
        print('🔍 Checking if user exists in Firestore...');
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          print('✅ User already exists in Firestore');
          // User already exists - this is fine, just return the credential
          return userCredential;
        }

        print('📝 Creating new user in Firestore...');
        // User doesn't exist - create user record in Firestore
        final displayName = userCredential.user!.displayName ?? '';
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        final lastName = nameParts.length > 1 
            ? nameParts.sublist(1).join(' ') 
            : '';

        try {
          final userData = {
          'firstName': firstName.isNotEmpty ? firstName : 'User',
          'lastName': lastName.isNotEmpty ? lastName : '',
          'email': userCredential.user!.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'signUpMethod': 'google',
          };
          print('📝 Writing user data to Firestore: $userData');
          await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
          print('✅ User created successfully in Firestore with ID: ${userCredential.user!.uid}');
          
          // Verify the user was created
          final verifyDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
          if (verifyDoc.exists) {
            print('✅ Verified: User document exists in Firestore');
          } else {
            print('⚠️ Warning: User document not found after creation');
          }
        } catch (e) {
          print('❌ Error creating user in Firestore: $e');
          print('❌ Error type: ${e.runtimeType}');
          // Re-throw the error so the user knows something went wrong
          // The user is authenticated but not saved - this is a problem
          throw Exception(
            'User account created but failed to save user data. '
            'Please contact support. Error: ${e.toString()}'
          );
        }
      }

      print('✅ Google Sign-Up completed successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        rethrow;
      }
      // Handle popup_closed error
      if (e.toString().contains('popup_closed') || 
          e.toString().contains('popup closed')) {
        throw Exception('Google Sign-Up was cancelled.');
      }
      // Handle CORS/COOP errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cross-origin') ||
          errorStr.contains('crossorigin') ||
          errorStr.contains('opener-policy') ||
          errorStr.contains('coop')) {
        throw Exception(
          'Google Sign-Up failed due to browser security settings. '
          'Please check your browser settings or try a different browser.'
        );
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
