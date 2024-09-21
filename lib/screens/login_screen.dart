import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'admin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _login() async {
    String mobile = _mobileController.text.trim();
    String password = _passwordController.text.trim();

    // Validate mobile number and password length
    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid mobile number')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid password')),
      );
      return;
    }

    try {
      // Fetch admin credentials from Firestore
      DocumentSnapshot adminDoc = await _firestore.collection('admin').doc('credentials').get();
      if (!adminDoc.exists) {
        throw Exception('Admin credentials not found.');
      }
      Map<String, dynamic>? adminData = adminDoc.data() as Map<String, dynamic>?;
      String? adminMobile = adminData?['mobile'];
      String? adminPassword = adminData?['password'];

      if (mobile == adminMobile && password == adminPassword) {
        // Admin login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminScreen()),
          );
        }
        return;
      }

      // Fetch user details from Firestore using mobile number
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(mobile).get();
      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mobile not registered')),
          );
        }
        return;
      }

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? approvalStatus = userData?['approval_status'];
      if (approvalStatus == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration is still pending approval')),
          );
        }
        return;
      } else if (approvalStatus == 'rejected') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration has been rejected')),
          );
        }
        return;
      }

      try {
        // Authenticate with Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: '${mobile}@example.com',
          password: password,
        );

        // Successful login for regular users
        String userRole = userData?['role'] ?? 'Patient';

        // Navigate to HomeScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid login credentials')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _mobileController,
              decoration: InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                );
              },
              child: Text('Forgot Password?'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: Text('New User? Register here'),
            ),
          ],
        ),
      ),
    );
  }
}
