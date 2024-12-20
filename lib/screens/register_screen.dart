import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedRole = 'Patient'; // Default role
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false; // Manage password visibility

  bool _isValidMobile(String mobile) {
    return mobile.length == 10 && !mobile.startsWith('0');
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  Future<String> generateUserId(String role) async {
    QuerySnapshot querySnapshot = await _firestore.collection('users')
        .where('role', isEqualTo: role)
        .get();

    int count = querySnapshot.docs.length;
    return '$role${count + 1}'; // Generates UserID like 'Patient12' or 'Doctor12'
  }

  Future<void> storeUserProfile(String uid, String mobile, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('user_profiles').doc(uid).set({
        'mobile': mobile,
        'userId': userId, // Store userId in profile
      });
    } catch (e) {
      print('Error storing user profile: $e');
    }
  }

  Future<void> _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String mobile = _mobileController.text.trim();
    String name = _nameController.text.trim();

    if (password.isEmpty || mobile.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (!_isValidMobile(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid mobile number')),
      );
      return;
    }

    if (!_isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters long')),
      );
      return;
    }

    try {
      // Check if the mobile number is already registered
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(mobile).get();
      if (userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mobile number is already registered')),
        );
        return;
      }

      // Register the user with Firebase Authentication using mobile number as email
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: '${mobile}@example.com',
        password: password,
      );

      // Get the UID of the registered user
      String uid = userCredential.user!.uid;

      // Generate userId based on the role
      String userId = await generateUserId(_selectedRole);

      // Save user details in Firestore
      await _firestore.collection('users').doc(mobile).set({
        'mobile': mobile,
        'name': name,
        'email': email,
        'role': _selectedRole,
        'approval_status': _selectedRole == 'Doctor' ? 'pending' : 'approved',
        'userId': userId, // Save the userId in the document
      });

      // Store user profile with mobile number and userId
      await storeUserProfile(uid, mobile, userId);

      if (_selectedRole == 'Doctor') {
        // Add to pending requests for admin approval
        await _firestore.collection('pending_requests').doc(mobile).set({
          'mobile': mobile,
          'role': _selectedRole,
          'email': email,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration pending approval for Doctor role')),
        );
      } else {
        // Log in the user if they're not a doctor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 100,  // Adjust size as needed
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
            ),
            TextField(
              controller: _mobileController,
              decoration: InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
            ),
            DropdownButton<String>(
              value: _selectedRole,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue!;
                });
              },
              items: <String>['Patient', 'Doctor']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: _register,
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
