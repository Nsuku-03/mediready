import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view medications.'),
        ),
      );
    }

    final medicationsQuery = FirebaseFirestore.instance
        .collection('medications')
        .where('patientId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: medicationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load medications.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Text('No medications found.'),
            );
          }

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final medication = documents[index].data();

              final name = medication['medicationName']
                  ?? 'Unnamed medication';
              final pharmacy = medication['pharmacyName']
                  ?? 'Not specified';
              final status = medication['status'] ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.medication),
                  title: Text(name.toString()),
                  subtitle: Text(
                    'Pharmacy: $pharmacy\nStatus: $status',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

