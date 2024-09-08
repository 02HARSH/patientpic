import 'package:cloud_firestore/cloud_firestore.dart';

// Model for image data
class ImageModel {
  final String? id;
  final String path;
  final String mobile;
  final DateTime timestamp;

  ImageModel({
    this.id,
    required this.path,
    required this.mobile,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'mobile': mobile,
      'timestamp': timestamp.toIso8601String(),
    };
  }factory ImageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ImageModel(
      id: doc['id'],
      path: data['path'] ?? '',
      mobile: data['mobile'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),  // Convert Firestore Timestamp to DateTime
    );
  }



}


class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseHelper._internal(); // Private constructor

  Future<void> addPrescription({
    required String imagePath,
    required String prescriptionPath,
    required String note,
  }) async {
    try {
      await _firestore.collection('prescriptions').add({
        'imagePath': imagePath,
        'prescriptionPath': prescriptionPath,
        'note': note,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding prescription: $e');
    }
  }

  Future<Map<String, dynamic>?> getPrescriptionForImage(String imagePath) async {
    try {
      final snapshot = await _firestore
          .collection('prescriptions')
          .where('imagePath', isEqualTo: imagePath)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error retrieving prescription: $e');
      return null;
    }
  }Future<void> insertImage(ImageModel image) async {
    try {
      final snapshot = await _firestore
          .collection('images')
          .where('mobile', isEqualTo: image.mobile)
          .get();

      final imageCount = snapshot.docs.length + 1;
      final imageId = '${image.mobile}_$imageCount';

      await _firestore.collection('images').doc(imageId).set({
        'id': imageId,
        'path': image.path,
        'mobile': image.mobile,
        'timestamp': Timestamp.fromDate(image.timestamp),  // Ensure this is a Timestamp
      });

      print('Image added with ID: $imageId');
    } catch (e) {
      print('Error inserting image: $e');
    }
  }



  Future<List<ImageModel>> getImages({String? mobile}) async {
    try {
      final query = mobile != null
          ? _firestore.collection('images').where('mobile', isEqualTo: mobile)
          : _firestore.collection('images');

      final snapshot = await query.get();
      print('Fetched ${snapshot.docs.length} images');
      return snapshot.docs.map((doc) => ImageModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error retrieving images: $e');
      return [];
    }
  }

  Future<List<String>> getUniqueMobiles() async {
    try {
      final snapshot = await _firestore.collection('images').get();
      final Set<String> uniqueMobiles = {};

      for (var doc in snapshot.docs) {
        uniqueMobiles.add(doc['mobile'] as String);
      }

      return uniqueMobiles.toList();
    } catch (e) {
      print('Error retrieving unique mobiles: $e');
      return [];
    }
  }

  Future<void> clearDatabase() async {
    try {
      final batch = _firestore.batch();
      final imagesSnapshot = await _firestore.collection('images').get();
      final prescriptionsSnapshot = await _firestore.collection('prescriptions').get();

      for (var doc in imagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      for (var doc in prescriptionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Database cleared');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  Future<void> close() async {
    // Firestore does not require explicit closing of connections.
  }
}
