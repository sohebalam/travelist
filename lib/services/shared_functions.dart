import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> updateUserInterests(List<String> newInterests) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentReference userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Get the current interests
      DocumentSnapshot snapshot = await userDoc.get();
      List<String> currentInterests =
          List<String>.from(snapshot.get('interests') ?? []);

      // Prepend new interests
      for (var interest in newInterests) {
        currentInterests.remove(interest); // Remove if already exists
        currentInterests.insert(0, interest); // Insert at the beginning
      }

      // Truncate the list if it exceeds 10 items
      if (currentInterests.length > 10) {
        currentInterests = currentInterests.sublist(0, 10);
      }

      // Update Firestore
      await userDoc.update({
        'interests': currentInterests,
      });
    }
  } catch (e) {
    print('Error updating user interests: $e');
  }
}
