import 'package:cloud_firestore/cloud_firestore.dart';

// Model for image
class ImageModel {
  final String? id;
  final String path;
  final String mobile;
  final DateTime timestamp;
  final String userId; // Add userId

  ImageModel({
    this.id,
    required this.path,
    required this.mobile,
    required this.timestamp,
    required this.userId, // Include userId in constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'mobile': mobile,
      'timestamp': Timestamp.fromDate(timestamp), // Ensure this is a Timestamp
      'userId': userId, // Add userId to the map
    };
  }

  factory ImageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ImageModel(
      id: data['id'],
      path: data['path'] ?? '',
      mobile: data['mobile'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
      userId: data['userId'] ?? '', // Add userId from Firestore
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
        'timestamp': Timestamp.now(),
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
  }
  Future<void> insertImage(ImageModel image) async {
    try {
      final snapshot = await _firestore
          .collection('images')
          .where('userId', isEqualTo: image.mobile)
          .get();

      final imageCount = snapshot.docs.length + 1;
      final imageId = '${image.mobile}_${image.userId}_$imageCount';

      await _firestore.collection('images').doc(imageId).set(image.toMap());
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

  Future<List<Map<String, String>>> getUniqueUsers() async {
    try {
      final snapshot = await _firestore.collection('images').get();

      final uniqueUsers = <Map<String, String>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final mobile = data['mobile'] as String?;

        if (userId != null && mobile != null) {
          uniqueUsers.add({'userId': userId, 'mobile': mobile});
        }
      }
      return uniqueUsers;
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
