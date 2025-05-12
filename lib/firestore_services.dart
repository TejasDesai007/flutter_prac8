import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  // Create
  Future<void> addUser(String name, String email, int age) {
    return users.add({
      'name': name,
      'email': email,
      'age': age,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read (stream)
  Stream<QuerySnapshot> getUsers() {
    return users.orderBy('createdAt', descending: true).snapshots();
  }

  // Update
  Future<void> updateUser(String docId, String name, String email, int age) {
    return users.doc(docId).update({
      'name': name,
      'email': email,
      'age': age,
    });
  }

  // Delete
  Future<void> deleteUser(String docId) {
    return users.doc(docId).delete();
  }
}
