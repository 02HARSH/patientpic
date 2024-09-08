import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../db/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'image_capture_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isDoctor = false;
  String? _userMobile;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkPrivileges();
  }Future<void> _checkPrivileges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user is currently logged in.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    Future<String?> _getUserMobileNumber(String uid) async {
      try {
        final userDoc = FirebaseFirestore.instance.collection('user_profiles').doc(uid);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          return data?['mobile'] as String?;
        } else {
          print('No data found for UID: $uid.');
          return null;
        }
      } catch (e) {
        print('Error fetching mobile number: $e');
        return null;
      }
    }

    final mobileNumber = await _getUserMobileNumber(user.uid);

    if (mobileNumber == null) {
      print('Could not retrieve mobile number for user with UID: ${user.uid}.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    print('Fetching data for user with mobile number: $mobileNumber');
    final userDoc = FirebaseFirestore.instance.collection('users').doc(mobileNumber);
    final userData = await userDoc.get();

    if (userData.exists) {
      setState(() {
        _userMobile = userData['mobile'];
        _userRole = userData['role'];
        isDoctor = _userRole == 'Doctor';
      });
      print('User data successfully retrieved.');
    } else {
      print('User data does not exist for mobile number: $mobileNumber.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }


  Future<List<String>> _getUniqueMobiles() async {
    return await DatabaseHelper.instance.getUniqueMobiles();
  }

  Future<List<ImageModel>> _getUserImages() async {
    final images = await DatabaseHelper.instance.getImages(mobile: _userMobile);
    print('Retrieved images: $images');
    return images;
  }

  Widget _buildImageGrid(List<ImageModel> images) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return GestureDetector(
          onTap: () => _showImageDialog(image),
          child: Image.file(
            File(image.path),
            width: 150,
            height: 150,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
  void _showImageDialog(ImageModel image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Image Details'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500, // Adjust height if needed
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Expanded(
                  child: PhotoView(
                    imageProvider: FileImage(File(image.path)),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Captured on: ${image.timestamp.toLocal()}',
                  style: TextStyle(fontSize: 16),
                ),
                if (isDoctor) ...[
                  TextButton(
                    onPressed: () => _uploadDocument(image.path),
                    child: Text('Upload Document'),
                  ),
                  TextButton(
                    onPressed: () => _showWriteNoteDialog(image),
                    child: Text('Write Note & Upload'),
                  ),
                  TextButton(
                    onPressed: () => _capturePrescription(image),
                    child: Text('Capture Prescription'),
                  ),
                ] else ...[
                  FutureBuilder<Map<String, dynamic>?>(
                    future: DatabaseHelper.instance.getPrescriptionForImage(image.path),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      } else if (snapshot.hasData && snapshot.data != null) {
                        final prescription = snapshot.data!;
                        return Column(
                          children: [
                            if (prescription['prescriptionPath'] != null)
                              TextButton(
                                onPressed: () => _downloadPrescription(prescription['prescriptionPath']),
                                child: Text('Download Prescription'),
                              ),
                            if (prescription['note'] != null)
                              Text('Note: ${prescription['note']}'),
                          ],
                        );
                      }
                      return Container(); // No prescription available
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showWriteNoteDialog(ImageModel image) {
    final _noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Write Note'),
          content: TextField(
            controller: _noteController,
            decoration: InputDecoration(labelText: 'Enter your note'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                String note = _noteController.text.trim();
                if (note.isNotEmpty) {
                  await DatabaseHelper.instance.addPrescription(
                    imagePath: image.path,
                    prescriptionPath: '',
                    note: note,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Note uploaded successfully')),
                  );
                }
              },
              child: Text('Upload'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _capturePrescription(ImageModel image) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.path.split('/').last}';

        // Upload the file to Firebase Storage
        Reference storageReference = FirebaseStorage.instance.ref().child('prescriptions/$fileName');
        UploadTask uploadTask = storageReference.putFile(file);

        await uploadTask.whenComplete(() async {
          if (uploadTask.snapshot.state == TaskState.success) {
            String downloadURL = await storageReference.getDownloadURL();
            print('Prescription captured and uploaded. File URL: $downloadURL');

            // Add prescription details to Firestore
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
              await userDoc.collection('prescriptions').add({
                'imagePath': pickedFile.path,
                'prescriptionPath': downloadURL,
                'timestamp': Timestamp.now(),
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Prescription uploaded successfully')),
              );
            }
          } else {
            print('Upload failed: ${uploadTask.snapshot.state}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed. Please try again.')),
            );
          }
        }).catchError((e) {
          print('Upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload prescription. Please try again.')),
          );
        });
      }
    } catch (e) {
      print('Capture and upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }Future<void> _downloadPrescription(String prescriptionPath) async {
    try {
      // Ensure the path starts with 'gs://' or 'https://'
      if (prescriptionPath.startsWith('gs://') || prescriptionPath.startsWith('https://')) {
        final storageReference = FirebaseStorage.instance.refFromURL(prescriptionPath);
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${prescriptionPath.split('/').last}');

        await storageReference.writeToFile(file);
        print('Download successful. File saved to ${file.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prescription downloaded successfully')),
        );
      } else {
        throw Exception('Invalid URL');
      }
    } catch (e) {
      print('Download failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download prescription. Please try again.')),
      );
    }
  }



  Future<void> _uploadDocument(String imagePath) async {
    try {
      File file = File(imagePath);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      Reference storageReference = FirebaseStorage.instance.ref().child('documents/$fileName');
      UploadTask uploadTask = storageReference.putFile(file);

      await uploadTask.whenComplete(() async {
        if (uploadTask.snapshot.state == TaskState.success) {
          String downloadURL = await storageReference.getDownloadURL();
          print('Document uploaded. File URL: $downloadURL');
        } else {
          print('Upload failed: ${uploadTask.snapshot.state}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed. Please try again.')),
          );
        }
      }).catchError((e) {
        print('Upload failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload document. Please try again.')),
        );
      });
    } catch (e) {
      print('Upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }
  void _showFullScreenImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FullScreenImageDialog(imagePath: imagePath);
      },
      barrierDismissible: true, // Allow dismiss by tapping outside
    );
  }Future<void> _writeNoteAndUpload(String imagePath) async {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Write Note'),
          content: TextField(
            controller: noteController,
            decoration: InputDecoration(hintText: 'Enter your note'),
            maxLines: 5,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _uploadNoteAndFile(imagePath, noteController.text);
              },
              child: Text('Upload Note'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadNoteAndFile(String imagePath, String note) async {
    try {
      File file = File(imagePath);
      String fileName = imagePath.split('/').last;

      Reference storageReference = FirebaseStorage.instance.ref().child('notes/$fileName');

      UploadTask uploadTask = storageReference.putFile(file);
      await uploadTask;

      String downloadURL = await storageReference.getDownloadURL();
      print('Upload successful with note. File URL: $downloadURL');

      await DatabaseHelper.instance.addPrescription(
        imagePath: imagePath,
        prescriptionPath: downloadURL,
        note: note,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note and file uploaded successfully')),
      );
    } catch (e) {
      print('Upload failed: $e');
    }
  }
  Future<void> _logout() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Optionally, you can perform any cleanup or logging out from other services if needed.

      // Sign out from Firebase Authentication
      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      // Handle case where user is not logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
          ),
        ],
      ),
      body: isDoctor
          ? FutureBuilder<List<String>>(
        future: _getUniqueMobiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final mobiles = snapshot.data!;
            return ListView.builder(
              itemCount: mobiles.length,
              itemBuilder: (context, index) {
                final mobile = mobiles[index];
                return ListTile(
                  title: Text(mobile),
                  onTap: () async {
                    final images = await DatabaseHelper.instance.getImages(mobile: mobile);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: Text('Images by $mobile'),
                          ),
                          body: _buildImageGrid(images),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImageCaptureScreen()),
                );
              },
              child: Text('Capture Image'),
            ),
            ElevatedButton(
              onPressed: () async {
                final images = await _getUserImages();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text('Your Captured Images'),
                      ),
                      body: _buildImageGrid(images),
                    ),
                  ),
                );
              },
              child: Text('View Captured Images'),)
          ],
        ),
      ),
    );
  }
}

class FullScreenImageDialog extends StatelessWidget {
  final String imagePath;

  FullScreenImageDialog({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
class FirebaseNoSignedInUserException implements Exception {
  final String message;
  FirebaseNoSignedInUserException(this.message);

  @override
  String toString() => 'FirebaseNoSignedInUserException: $message';
}
