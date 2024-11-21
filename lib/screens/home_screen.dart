import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../db/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:result_type/result_type.dart';
import 'image_capture_screen.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isDoctor = false;
  String? _userMobile;
  static const Duration _timeoutDuration = Duration(
      seconds: 1); // Timeout duration

  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPrivileges();
  }

  Future<void> _checkPrivileges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    Future<String?> _getUserMobileNumber(String uid) async {
      try {
        final userDoc = FirebaseFirestore.instance.collection('user_profiles')
            .doc(uid);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          return data?['mobile'] as String?;
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }

    Future<void> _fetchData() async {
      final mobileNumber = await _getUserMobileNumber(user.uid);

      if (mobileNumber == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
        return;
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(
          mobileNumber);
      final userData = await userDoc.get();

      if (userData.exists) {
        setState(() {
          _userMobile = userData['mobile'];
          _userRole = userData['role'];
          isDoctor = _userRole == 'Doctor';
          _isLoading = false;
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }

    try {
      await Future.any([
        _fetchData(),
        Future.delayed(_timeoutDuration),
      ]);
    } catch (e) {
      // Handle any errors that might occur during the fetch
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }

    // If still loading after timeout, assume failure
    if (mounted && _isLoading) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
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
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to the new page when the image is clicked
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FullScreenImagePage(imagePath: image.path),
                        ),
                      );
                    },
                    child: PhotoView(
                      imageProvider: FileImage(File(image.path)),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                    ),
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
                ] else
                  ...[
                    FutureBuilder<bool>(
                      future: _hasPrescriptions(image.path),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data == true) {
                          return TextButton(
                            onPressed: () => _showDownloadDialog(image.path),
                            child: Text('Download Prescription'),
                          );
                        } else if (snapshot.hasData && snapshot.data == false) {
                          return Text('No prescription available');
                        }
                        return Container(); // No data or error
                      },
                    ),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: DatabaseHelper.instance.getPrescriptionForImage(
                          image.path),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data != null) {
                          final prescription = snapshot.data!;
                          return Column(
                            children: [
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


  void _showDownloadDialog(String prescriptionPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Download Prescription'),
          content: Text('Do you want to download this prescription?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _retrieveLatestPrescription(
                    prescriptionPath); // Call the download function
              },
              child: Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  Future<void> _retrieveLatestPrescription(String imagePath) async {
    try {
      print('Retrieving latest prescription for: $imagePath');
      final imageDocumentId = await _getImageDocumentId(imagePath);
      print('Image Document ID: $imageDocumentId');

      if (imageDocumentId != null) {
        final prescriptionsSnapshot = await FirebaseFirestore.instance
            .collection('images')
            .doc(imageDocumentId)
            .collection('prescriptions')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (prescriptionsSnapshot.docs.isNotEmpty) {
          final latestPrescription = prescriptionsSnapshot.docs.first.data();
          final prescriptionPath = latestPrescription['prescriptionPath'] as String?;

          print('Prescription Path: $prescriptionPath');

          if (prescriptionPath != null) {
            await _requestPermissions();
            await _downloadPrescription(prescriptionPath);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No prescription path available')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No prescriptions found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to find image document')),
        );
      }
    } catch (e) {
      print('Failed to retrieve prescription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Failed to retrieve prescription. Please try again.')),
      );
    }
  }

  Future<void> _downloadPrescription(String prescriptionPath) async {
    try {
      await _requestPermissions(); // Ensure permissions are requested

      final directory = Directory(
          '/storage/emulated/0/Download'); // Public Downloads folder

      if (!directory.existsSync()) {
        throw Exception("Downloads directory not found.");
      }

      // Fetch the file from the URL
      final response = await http.get(Uri.parse(prescriptionPath));

      if (response.statusCode == 200) {
        // Extract the file name from the URL
        final fileName = p.basename(Uri
            .parse(prescriptionPath)
            .path);
        final file = File('${directory.path}/$fileName');

        // Write the file to the Downloads directory
        await file.writeAsBytes(response.bodyBytes);

        print('Download successful. File saved to ${file.path}');
        // Open the file using the default app
        final result = await OpenFile.open(file.path);

        // Check if the result is null or not
        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Prescription downloaded but failed to open')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Prescription downloaded and opened successfully')),
          );
        }
      } else {
        throw Exception(
            'Failed to load file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Download failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Failed to download prescription. Please try again.')),
      );
    }
  }


  Future<bool> _hasPrescriptions(String imagePath) async {
    try {
      final imageDocumentId = await _getImageDocumentId(imagePath);

      if (imageDocumentId != null) {
        final prescriptionsSnapshot = await FirebaseFirestore.instance
            .collection('images')
            .doc(imageDocumentId)
            .collection('prescriptions')
            .limit(1)
            .get();

        return prescriptionsSnapshot.docs.isNotEmpty;
      } else {
        print('Failed to find image document');
        return false;
      }
    } catch (e) {
      print('Error checking prescriptions: $e');
      return false;
    }
  }

  Future<void> _capturePrescription(ImageModel image) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String fileName = '${DateTime
            .now()
            .millisecondsSinceEpoch}_${pickedFile.path
            .split('/')
            .last}';

        Reference storageReference = FirebaseStorage.instance.ref().child(
            'prescriptions/$fileName');
        UploadTask uploadTask = storageReference.putFile(file);

        await uploadTask.whenComplete(() async {
          if (uploadTask.snapshot.state == TaskState.success) {
            String downloadURL = await storageReference.getDownloadURL();
            print('Prescription captured and uploaded. File URL: $downloadURL');

            final imagePath = image.path;
            final imageDocumentId = await _getImageDocumentId(imagePath);

            if (imageDocumentId != null) {
              await FirebaseFirestore.instance
                  .collection('images')
                  .doc(imageDocumentId)
                  .collection('prescriptions')
                  .add({
                'prescriptionPath': downloadURL,
                'timestamp': Timestamp.now(),
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Prescription uploaded successfully')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to find image document')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed. Please try again.')),
            );
          }
        }).catchError((e) {
          print('Upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Failed to upload prescription. Please try again.')),
          );
        });
      }
    } catch (e) {
      print('Capture and upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  Future<String?> _getImageDocumentId(String imagePath) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('images')
          .where('path', isEqualTo: imagePath)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final document = querySnapshot.docs.first;
        return document.id; // Return the document ID
      } else {
        print('No document found with path: $imagePath');
        return null;
      }
    } catch (e) {
      print('Error retrieving image document ID: $e');
      return null;
    }
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


  Future<void> _uploadDocument(String imagePath) async {
    try {
      // Open file picker to select documents (pdf, doc, etc.)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt'
        ], // Add file types you want to allow
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = '${DateTime
            .now()
            .millisecondsSinceEpoch}_${file.path
            .split('/')
            .last}';

        // Save document in 'prescriptions' folder in Firebase Storage
        Reference storageReference = FirebaseStorage.instance.ref().child(
            'prescriptions/$fileName');
        UploadTask uploadTask = storageReference.putFile(file);

        await uploadTask.whenComplete(() async {
          if (uploadTask.snapshot.state == TaskState.success) {
            String downloadURL = await storageReference.getDownloadURL();
            print('Document uploaded. File URL: $downloadURL');

            // Associate the document with the image's prescriptions collection
            final imageDocumentId = await _getImageDocumentId(imagePath);

            if (imageDocumentId != null) {
              await FirebaseFirestore.instance
                  .collection('images')
                  .doc(imageDocumentId)
                  .collection('prescriptions')
                  .add({
                'prescriptionPath': downloadURL,
                'timestamp': Timestamp.now(),
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Document uploaded successfully')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to find image document')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed. Please try again.')),
            );
          }
        }).catchError((e) {
          print('Upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to upload document. Please try again.')),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No document selected')),
        );
      }
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
  }

  Future<void> _writeNoteAndUpload(String imagePath) async {
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
      String fileName = imagePath
          .split('/')
          .last;

      Reference storageReference = FirebaseStorage.instance.ref().child(
          'notes/$fileName');

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

  Future<List<Map<String, String>>> _getUniqueUsers() async {
    // Get the list of unique users with both userId and mobile
    return await DatabaseHelper.instance.getUniqueUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading spinner while data is being fetched
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
          ),
        ],
        backgroundColor: Colors.blueAccent,
      ),
      body: isDoctor
          ? FutureBuilder<List<Map<String, String>>>(
        future: _getUniqueUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final users = snapshot.data!;
            return ListView.separated(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userId = users[index]['userId'];
                final mobile = users[index]['mobile'];
                final folderName = '$userId($mobile)';
                return ListTile(
                  title: Text(folderName),
                  onTap: () async {
                    final images = await DatabaseHelper.instance.getImages(
                        mobile: mobile);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            Scaffold(
                              appBar: AppBar(
                                title: Text('Images by $folderName'),
                              ),
                              body: _buildImageGrid(images),
                            ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) =>
                  Divider(
                    color: Colors.grey,
                    thickness: 1,
                  ),
            );
          }
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImageCaptureScreen()),
                );
              },
              icon: Icon(Icons.camera_alt), // Add a camera icon
              label: Text('Capture Image'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 60), // Increase width and height
                textStyle: TextStyle(
                    fontSize: 16), // Improve font size for better UX
              ),
            ),
            SizedBox(height: 20), // Add some spacing between buttons
            ElevatedButton.icon(
              onPressed: () async {
                final images = await _getUserImages();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(
                          appBar: AppBar(
                            title: Text('Your Captured Images'),
                            backgroundColor: Colors.blueAccent,
                          ),
                          body: _buildImageGrid(images),
                        ),
                  ),
                );
              },
              icon: Icon(Icons.image), // Add an image icon
              label: Text('View Captured Images'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 60), // Increase width and height
                textStyle: TextStyle(
                    fontSize: 16), // Improve font size for better UX
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel any timers or listeners here if you have them
    super.dispose();
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
class FullScreenImagePage extends StatelessWidget {
  final String imagePath;

  FullScreenImagePage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image View'),
        automaticallyImplyLeading: false, // Disable back button
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop(); // Close the image view
            },
          ),
        ],
      ),
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(File(imagePath)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3, // Allow more zoom on the new page
        ),
      ),
    );
  }
}