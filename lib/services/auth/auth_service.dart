import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      return user;
    } catch (e) {
      print('Error signing in with email and password: $e');
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = result.user;
      if (user != null) {
        await saveUserToFirestore(user, user.displayName, user.photoURL);
      }
      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  Stream<User?> get user => _firebaseAuth.authStateChanges();

  Future<void> saveUserToFirestore(
      User user, String? name, String? image) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final DocumentSnapshot doc = await userRef.get();
      bool isAdmin = false;
      String? existingImage;

      if (doc.exists) {
        // Preserve existing isAdmin value and image if the document exists
        isAdmin = doc['isAdmin'] ?? false;
        existingImage = doc['image'] as String?;
      }

      await userRef.set({
        'email': user.email ?? '',
        'name': name,
        'image': image ??
            existingImage, // Preserve the existing image if a new one is not provided
        'uid': user.uid,
        'date': DateTime.now(),
        'interests': FieldValue.arrayUnion(
            []), // Initialize interests as empty array if not present
        'isAdmin': isAdmin, // Preserve or set default isAdmin flag
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  Future<List<String>> getUserInterests(User user) async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (userSnapshot.exists) {
        Map<String, dynamic> userData =
            userSnapshot.data() as Map<String, dynamic>;
        List<String> interests = List<String>.from(userData['interests'] ?? []);
        return interests;
      }
    } catch (e) {
      print('Error loading user interests: $e');
    }
    return [];
  }
}
