import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Make sure this import is correct

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection(
          'pending_requests').get();
      setState(() {
        _pendingRequests =
            querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch pending requests: $e')),
      );
    }
  }

  Future<void> _approveRequest(String mobile) async {
    try {
      // Remove from pending requests
      await _firestore.collection('pending_requests').doc(mobile).delete();

      // Update user approval status
      await _firestore.collection('users').doc(mobile).update({
        'approval_status': 'approved',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request approved')),
      );

      // Refresh pending requests list
      await _fetchPendingRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve request: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String mobile) async {
    try {
      // Remove from pending requests
      await _firestore.collection('pending_requests').doc(mobile).delete();

      // Update user approval status
      await _firestore.collection('users').doc(mobile).update({
        'approval_status': 'rejected',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request rejected')),
      );

      // Refresh pending requests list
      await _fetchPendingRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject request: $e')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        backgroundColor: Colors.blueAccent,
      ),
      body: _pendingRequests.isEmpty
          ? Center(child: Text('No pending requests'))
          : ListView.separated(
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          Map<String, dynamic> request = _pendingRequests[index];
          return ListTile(
            title: Text('Mobile: ${request['mobile']}'),
            subtitle: Text('Role: ${request['role']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () => _approveRequest(request['mobile']),
                ),
                IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () => _rejectRequest(request['mobile']),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) =>
            Divider(
              color: Colors.grey, // Customize the color
              thickness: 1, // Set the thickness of the line
            ),
      ),
    );
  }
}