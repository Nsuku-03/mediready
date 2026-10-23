
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pharmacy_dashboard.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


Future<void> setupNotifications() async {
  print('MEDIREADY: Notification setup started');

  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print(
      'MEDIREADY: Notification permission: '
          '${settings.authorizationStatus}',
    );

    final token = await messaging.getToken();
    print('MEDIREADY: FCM token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'MEDIREADY: Notification received: '
            '${message.notification?.title}',
      );
      print('MEDIREADY: Message: ${message.notification?.body}');
    });
  } catch (e) {
    print('MEDIREADY: Notification setup error: $e');
  }
}

Future<void> savePatientFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print('MEDIREADY: No signed-in patient to save token for.');
    return;
  }

  try {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null) {
      print('MEDIREADY: FCM token is not available yet.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('patients')
        .doc(user.uid)
        .set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('MEDIREADY: Patient FCM token saved successfully.');
  } catch (e) {
    print('MEDIREADY: Could not save patient FCM token: $e');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await setupNotifications();

  runApp(const MediReadyApp());
}

class MediReadyApp extends StatelessWidget {
  const MediReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediReady',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// HOME SCREEN

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediReady'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.medication,
                size: 90,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to MediReady',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Manage your medication collection '
                    'with confidence and convenience.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Patient Registration'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const PatientRegistrationScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.medication_outlined),
                  label: const Text('My Medications'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicationsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.local_pharmacy),
                  label: const Text('Pharmacy Staff Login'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const PharmacyStaffLoginScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PATIENT REGISTRATION

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your phone number with country code, '
                'for example +27XXXXXXXXX.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await FirebaseAuth.instance
                .signInWithCredential(credential);

            await _savePatient(result.user!.uid);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification failed: $e')),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ?? 'Could not send verification SMS.',
              ),
            ),
          );

          setState(() => _loading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() => _loading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmsVerificationScreen(
                verificationId: verificationId,
                name: _nameController.text.trim(),
                idNumber: _idController.text.trim(),
                phoneNumber: phone,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Registration failed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePatient(String uid) async {
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .set({
      'name': _nameController.text.trim(),
      'idNumber': _idController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 70,
                color: Colors.teal,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter your ID number'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number (+27...)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Include your country code.',
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter your phone number'
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('REGISTER AND VERIFY PHONE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SMS VERIFICATION

class SmsVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String name;
  final String idNumber;
  final String phoneNumber;

  const SmsVerificationScreen({
    super.key,
    required this.verificationId,
    required this.name,
    required this.idNumber,
    required this.phoneNumber,
  });

  @override
  State<SmsVerificationScreen> createState() =>
      _SmsVerificationScreenState();
}

class _SmsVerificationScreenState
    extends State<SmsVerificationScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the SMS verification code.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final result =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = result.user;

      if (user == null) {
        throw Exception('Could not verify your phone number.');
      }

      await FirebaseFirestore.instance
          .collection('patients')
          .doc(user.uid)
          .set({
        'name': widget.name,
        'idNumber': widget.idNumber,
        'phoneNumber': widget.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await savePatientFcmToken();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const RegistrationSuccessScreen(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Invalid verification code. Try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save patient details: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms, size: 70, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              'Enter the code sent to your phone.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'SMS verification code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('VERIFY'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// REGISTRATION SUCCESS

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration Complete')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 90,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              const Text(
                'Registration successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your phone number has been verified.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicationsScreen(),
                    ),
                        (route) => false,
                  );
                },
                child: const Text('VIEW MY MEDICATIONS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PATIENT MEDICATION LIST

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ready':
        return Colors.green;
      case 'preparing':
        return Colors.orange.shade800;
      case 'collected':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'preparing':
        return Icons.schedule;
      case 'collected':
        return Icons.inventory_2_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Medications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: user == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 60,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please register and verify your phone number '
                    'to view your medications.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const PatientRegistrationScreen(),
                    ),
                  );
                },
                child: const Text('PATIENT REGISTRATION'),
              ),
            ],
          ),
        ),
      )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('patientId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load medications. Check your '
                      'connection and Firestore permissions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.teal,
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No medications yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your medications will appear here '
                          'when the pharmacy adds them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          documents.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aDate = aTime is Timestamp
                ? aTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            final bDate = bTime is Timestamp
                ? bTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Your medication collection',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check your pharmacy and collection status below.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ...documents.map((document) {
                final data = document.data();

                final medicationName =
                    data['medicationName']?.toString() ??
                        'Medication';
                final pharmacyName =
                    data['pharmacyName']?.toString() ??
                        'Pharmacy not specified';
                final status =
                    data['status']?.toString() ?? 'Unknown';
                final color = _statusColor(status);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.teal.shade50,
                      child: const Icon(
                        Icons.medication_outlined,
                        color: Colors.teal,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      medicationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.local_pharmacy_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: Text(pharmacyName)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.teal,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicationDetailsScreen(
                                medicationName: medicationName,
                                pharmacyName: pharmacyName,
                                status: status,
                                medicationId: document.id,
                              ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}


// MEDICATION DETAILS


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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Could not load medications. Check Firestore rules '
                      'and make sure you are signed in as pharmacy staff.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
    );
  }
}

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

class _MedicationStatusCardState extends State<MedicationStatusCard> {
  static const List<String> statuses = [
    'Preparing',
    'Ready',
    'Collected',
  ];

  late String selectedStatus;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final current = widget.data['status']?.toString() ?? 'Preparing';

    selectedStatus = statuses.contains(current) ? current : 'Preparing';
  }

  Future<void> updateStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('medications')
          .doc(widget.medicationId)
          .update({
        'status': selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $selectedStatus.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Update denied by Firestore rules. Check the medication '
                'record fields and staff authorization.'
                : 'Could not update status: ${e.message ?? e.code}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicationName =
        widget.data['medicationName']?.toString() ?? 'Medication';
    final pharmacyName =
        widget.data['pharmacyName']?.toString() ?? 'Pharmacy not specified';
    final patientId =
        widget.data['patientId']?.toString() ?? 'Unknown';

    final currentStatus =
        widget.data['status']?.toString() ?? 'Unknown';

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
            Text('Patient ID: $patientId'),
            Text('Current status: $currentStatus'),
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
                  setState(() => selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saving || selectedStatus == currentStatus
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
                label: Text(saving ? 'Updating...' : 'Update Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationDetailsScreen extends StatelessWidget {
  final String medicationName;
  final String pharmacyName;
  final String status;
  final String medicationId;

  const MedicationDetailsScreen({
    super.key,
    required this.medicationName,
    required this.pharmacyName,
    required this.status,
    required this.medicationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicationName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Pharmacy: $pharmacyName'),
                const SizedBox(height: 12),
                Text('Status: $status'),
                const SizedBox(height: 12),
                Text('Medication ID: $medicationId'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
