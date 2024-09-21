import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _sendResetLink() async {
    String mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid mobile number')),
      );
      return;
    }

    try {
      // Verify phone number by sending OTP
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$mobile', // assuming the mobile number is Indian (+91)
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Automatically verifies and signs in the user.
          await _auth.signInWithCredential(credential);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone number automatically verified.')),
          );
          _showResetPasswordDialog(); // Show reset password option directly
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          // Code has been sent to the mobile number
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP has been sent to +91$mobile')),
          );

          // Now you can prompt the user to enter the OTP and use it for reset
          _showOtpDialog(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval time expired
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $e')),
      );
    }
  }

  void _showOtpDialog(String verificationId) {
    final TextEditingController _otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter OTP'),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'OTP'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Get the OTP entered by the user
              String otp = _otpController.text.trim();

              // Create a credential using the OTP and verification ID
              PhoneAuthCredential credential = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: otp,
              );

              try {
                // Sign in the user using the OTP credential
                await _auth.signInWithCredential(credential);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Phone number verified.')),
                );
                Navigator.pop(context); // Close the OTP dialog
                _showResetPasswordDialog(); // Show the password reset option
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid OTP: $e')),
                );
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    final TextEditingController _newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password'),
        content: TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              String newPassword = _newPasswordController.text.trim();

              if (newPassword.isEmpty || newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid password (min 6 characters)')),
                );
                return;
              }

              try {
                // Assuming user is signed in with phone and has a valid FirebaseUser
                User? user = _auth.currentUser;
                if (user != null) {
                  await user.updatePassword(newPassword);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset successful')),
                  );
                  Navigator.pop(context); // Close the reset password dialog
                  Navigator.pop(context); // Go back to login screen
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to reset password: $e')),
                );
              }
            },
            child: Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forgot Password'),
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
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _sendResetLink,
              child: Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
