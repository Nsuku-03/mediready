
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ======================================================
// PHARMACY STAFF LOGIN
// ======================================================

class PharmacyStaffLoginScreen extends StatefulWidget {
  const PharmacyStaffLoginScreen({super.key});

  @override
  State<PharmacyStaffLoginScreen> createState() =>
      _PharmacyStaffLoginScreenState();
}

class _PharmacyStaffLoginScreenState
    extends State<PharmacyStaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _resetting = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your registered staff email first.'),
        ),
      );
      return;
    }

    setState(() => _resetting = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent. Please check your inbox.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Could not send password reset email.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

      final staffDocument = await FirebaseFirestore.instance
          .collection('staff')
          .doc(user.uid)
          .get();

      if (!staffDocument.exists ||
          staffDocument.data()?['role'] != 'pharmacy') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access denied. This account is not registered '
                  'as pharmacy staff.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PharmacyDashboard(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Login failed. Check your details.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not verify staff access: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Staff Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/pharmacy_staff_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.teal.shade50);
            },
          ),
          Container(
            color: Colors.white.withOpacity(0.72),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_pharmacy,
                      size: 80,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MediReady Pharmacy Portal',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Staff email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                        _resetting ? null : _resetPassword,
                        child: _resetting
                            ? const Text('Sending reset email...')
                            : const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('LOGIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ======================================================
// PHARMACY DASHBOARD
// ======================================================

class PharmacyDashboard extends StatelessWidget {
  const PharmacyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const PharmacyStaffLoginScreen(),
                ),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/pharmacy_staff_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.teal.shade50);
            },
          ),
          Container(
            color: Colors.white.withOpacity(0.72),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('medications')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load medications. Check your '
                          'Firestore rules and medication records.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final medications = snapshot.data?.docs ?? [];

              if (medications.isEmpty) {
                return const Center(
                  child: Text('No medication requests found.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: medications.length,
                itemBuilder: (context, index) {
                  final document = medications[index];

                  return MedicationStatusCard(
                    key: ValueKey(document.id),
                    medicationId: document.id,
                    data: document.data(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}


// ======================================================
// MEDICATION STATUS CARD
// ======================================================

class MedicationStatusCard extends StatefulWidget {
  final String medicationId;
  final Map<String, dynamic> data;

  const MedicationStatusCard({
    super.key,
    required this.medicationId,
    required this.data,
  });

  @override
  State<MedicationStatusCard> createState() =>
      _MedicationStatusCardState();
}

class _MedicationStatusCardState
    extends State<MedicationStatusCard> {
  static const statuses = [
    'Preparing',
    'Ready',
    'Collected',
  ];

  late String selectedStatus;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final current =
        widget.data['status']?.toString() ?? 'Preparing';

    selectedStatus =
    statuses.contains(current) ? current : 'Preparing';
  }

  @override
  void didUpdateWidget(
      covariant MedicationStatusCard oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data['status'] != widget.data['status']) {
      final current =
          widget.data['status']?.toString() ?? 'Preparing';

      selectedStatus =
      statuses.contains(current) ? current : 'Preparing';
    }
  }

  // ====================================================
  // UPDATE STATUS AND CREATE PATIENT NOTIFICATION
  // ====================================================

  Future<void> updateStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again.'),
        ),
      );
      return;
    }

    final patientId =
    widget.data['patientId']?.toString();

    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot notify patient: patient ID is missing.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final medicationRef = FirebaseFirestore.instance
          .collection('medications')
          .doc(widget.medicationId);

      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();

      final medicationName =
          widget.data['medicationName']?.toString() ??
              'Medication';

      final pharmacyName =
          widget.data['pharmacyName']?.toString() ??
              'Pharmacy';

      String message;

      if (selectedStatus == 'Preparing') {
        message =
        'Your $medicationName is now being prepared '
            'at $pharmacyName.';
      } else if (selectedStatus == 'Ready') {
        message =
        'Your $medicationName is ready for collection '
            'at $pharmacyName.';
      } else if (selectedStatus == 'Collected') {
        message =
        'Your $medicationName has been marked as collected.';
      } else {
        message = 'Your medication status has been updated.';
      }

      final batch = FirebaseFirestore.instance.batch();

      // Update the medication record.
      batch.update(medicationRef, {
        'status': selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'notificationPending': true,
        'notificationSent': false,
        'notificationQueuedAt':
        FieldValue.serverTimestamp(),
      });

      // Create a notification for the patient.
      batch.set(notificationRef, {
        'patientId': patientId,
        'medicationId': widget.medicationId,
        'medicationName': medicationName,
        'pharmacyName': pharmacyName,
        'status': selectedStatus,
        'title': 'Medication status updated',
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'updatedBy': user.uid,
      });

      // Both operations succeed together or fail together.
      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status updated and patient notification created: '
                '$selectedStatus',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Permission denied. Check your Firestore '
                'rules and pharmacy staff authorization.'
                : 'Update failed: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  // ====================================================
  // MEDICATION CARD DISPLAY
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final medicationName =
        widget.data['medicationName']?.toString() ??
            'Medication';

    final pharmacyName =
        widget.data['pharmacyName']?.toString() ??
            'Unknown pharmacy';

    final patientId =
        widget.data['patientId']?.toString() ??
            'Unknown';

    final currentStatus =
        widget.data['status']?.toString() ??
            'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicationName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text('Pharmacy: $pharmacyName'),

            const SizedBox(height: 4),

            Text('Patient ID: $patientId'),

            const SizedBox(height: 4),

            Text(
              'Current status: $currentStatus',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'New collection status',
                border: OutlineInputBorder(),
              ),
              items: statuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: saving
                  ? null
                  : (value) {
                if (value != null) {
                  setState(() {
                    selectedStatus = value;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                saving || selectedStatus == currentStatus
                    ? null
                    : updateStatus,
                icon: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  saving
                      ? 'Updating...'
                      : 'Update Status',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
