import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListService {
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  Future<List<QueryDocumentSnapshot>> getUserLists() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    QuerySnapshot snapshot = await _listsCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .get();
    return snapshot.docs;
  }

  Stream<QuerySnapshot> streamUserLists() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    return _listsCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .snapshots();
  }

  Future<void> deleteList(String listId) async {
    await _listsCollection.doc(listId).delete();
  }

  Future<void> createList(String listName) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _listsCollection.add({
        'list': listName,
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<QuerySnapshot> getPOIsForList(String listId) async {
    return await _listsCollection.doc(listId).collection('pois').get();
  }
}
