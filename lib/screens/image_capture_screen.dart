import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/database_helper.dart';

class ImageCaptureScreen extends StatefulWidget {
  @override
  _ImageCaptureScreenState createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _userMobile;
  String? _userId;
  @override
  void initState() {
    super.initState();
    _loadUserMobile();
  }
  Future<void> _loadUserMobile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Query the 'user_profiles' collection using user.uid as the document ID
        final userDoc = await FirebaseFirestore.instance.collection('user_profiles').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userMobile = userDoc.data()?['mobile'];
            // Assuming the user ID is stored in the 'userId' field
            _userId = userDoc.data()?['userId'];
          });
          // Print the mobile number for debugging
          print('User mobile number: $_userMobile');
          print('User ID: $_userId');
        } else {
          print('User document does not exist in user_profiles collection.');
        }
      } else {
        print('No user is currently signed in.');
      }
    } catch (e) {
      print('Error loading user mobile: $e');
    }
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final directory = await _getDirectoryForMobile();
        final imagePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageFile = File(pickedFile.path);
        await imageFile.copy(imagePath);

        if (_userMobile != null) {
          final imageModel = ImageModel(
            path: imagePath,
            mobile: _userMobile!,
            timestamp: DateTime.now(),
            userId: _userId!,
          );

          // Insert the image into Firestore with the mobile-based ID
          await DatabaseHelper.instance.insertImage(imageModel);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image captured and saved successfully')),
          );
        }
      } else {
        print("No image selected");
      }
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  Future<void> updateTimestamps() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    try {
      final snapshot = await _firestore.collection('images').get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['timestamp'] is String) {
          final timestamp = Timestamp.fromDate(DateTime.parse(data['timestamp'] as String));
          await _firestore.collection('images').doc(doc.id).update({'timestamp': timestamp});
          print('Updated timestamp for document ID: ${doc.id}');
        }
      }
    } catch (e) {
      print('Error updating timestamps: $e');
    }
  }Future<Directory> _getDirectoryForMobile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Ensure userId and mobile are not null
      if (_userId == null || _userMobile == null) {
        throw Exception('User ID or mobile number is not set.');
      }
      print(_userId);
      // Construct folder name with both user ID and mobile number
      final folderName = '${_userId}(${_userMobile})';
      final mobileDirectory = Directory('${directory.path}/images/$folderName');
      print('Folder name: $folderName');
      print('Full path: ${directory.path}/images/$folderName');
      if (!await mobileDirectory.exists()) {
        await mobileDirectory.create(recursive: true);
      }
      return mobileDirectory;
    } catch (e) {
      print('Error getting directory for mobile: $e');
      rethrow;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capture Image'),
        backgroundColor: Colors.blueAccent, // Enhanced AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _captureImage(ImageSource.camera),
              icon: Icon(Icons.camera_alt, size: 30), // Larger icon
              label: Text(
                'Capture Image with Camera',
                style: TextStyle(fontSize: 18), // Improved text style
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60), // Full-width button
                padding: EdgeInsets.symmetric(horizontal: 16), // Padding inside button
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _captureImage(ImageSource.gallery),
              icon: Icon(Icons.photo_library, size: 30), // Larger icon
              label: Text(
                'Select Image from Gallery',
                style: TextStyle(fontSize: 18), // Improved text style
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60), // Full-width button
                padding: EdgeInsets.symmetric(horizontal: 16), // Padding inside button
              ),
            ),
          ],
        ),
      ),
    );
  }

}
