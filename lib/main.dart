import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pharmacy_dashboard.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'dart:ui';

Future<void> setupNotifications() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(
    tz.getLocation('Africa/Johannesburg'),
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel medicationChannel =
  AndroidNotificationChannel(
    'mediready_medication_channel',
    'Medication Reminders',
    description: 'Notifications about medication status and reminders.',
    importance: Importance.max,
  );
  print('MEDIREADY: Notification setup started');

  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
    );
    final androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(medicationChannel);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );


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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      if (notification == null) return;

      await flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title ?? 'MediReady',
        body: notification.body ?? 'You have a medication update.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mediready_medication_channel',
            'Medication Reminders',
            channelDescription:
            'Notifications about medication status and reminders.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );

      print('MEDIREADY: Foreground notification displayed.');
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
      home: const WelcomeScreen(),
    );
  }
}


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediReadyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                const Icon(
                  Icons.medical_services,
                  color: Colors.teal,
                  size: 100,
                ),

                const SizedBox(height: 20),

                const Text(
                  'MediReady',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Your medication collection made easier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Manage medications, receive updates '
                      'and stay on track with your reminders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'MediReady • Your health, organised.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// HOME SCREEN



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.92),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 17),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediReady'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 25),

              const Icon(
                Icons.medical_services,
                size: 75,
                color: Colors.teal,
              ),

              const SizedBox(height: 15),

              const Text(
                'Welcome to MediReady',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Your medication management companion. '
                    'Stay informed, organised and on time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 25),

              menuCard(
                icon: Icons.person,
                title: 'Patient Portal',
                subtitle:
                'Register, view medications and manage reminders.',
                color: Colors.teal,
                onTap: () {
                  openPage(context, const PatientAccessScreen());
                },
              ),

              const SizedBox(height: 12),

              menuCard(
                icon: Icons.local_pharmacy,
                title: 'Pharmacy Staff Portal',
                subtitle:
                'Sign in to manage patient medications and updates.',
                color: Colors.blue,
                onTap: () {
                  openPage(
                    context,
                    const PharmacyStaffLoginScreen(),
                  );
                },
              ),

              const SizedBox(height: 12),

              menuCard(
                icon: Icons.info_outline,
                title: 'About MediReady',
                subtitle: 'Learn about our application and services.',
                color: Colors.deepPurple,
                onTap: () {
                  openPage(context, const AboutMediReadyScreen());
                },
              ),

              const SizedBox(height: 12),

              menuCard(
                icon: Icons.help_outline,
                title: 'Help and Support',
                subtitle: 'Find assistance with using MediReady.',
                color: Colors.orange,
                onTap: () {
                  openPage(context, const HelpSupportScreen());
                },
              ),

              const SizedBox(height: 12),

              menuCard(
                icon: Icons.phone,
                title: 'Contact Us',
                subtitle: 'Get in touch with the pharmacy.',
                color: Colors.green,
                onTap: () {
                  openPage(context, const ContactPharmacyScreen());
                },
              ),

              const SizedBox(height: 12),

              menuCard(
                icon: Icons.location_on,
                title: 'Pharmacy Location',
                subtitle: 'View the pharmacy address and location.',
                color: Colors.red,
                onTap: () {
                  openPage(context, const PharmacyLocationScreen());
                },
              ),

              const SizedBox(height: 25),

              const Text(
                'MediReady • Your health, organised.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


class PatientAccessScreen extends StatelessWidget {
  const PatientAccessScreen({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Portal'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 75,
                  color: Colors.teal,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Patient Services',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to MediReady Patient Services. '
                      'Choose an option to access your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 35),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('NEW PATIENT REGISTRATION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      openPage(
                        context,
                        const PatientRegistrationScreen(),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('EXISTING PATIENT LOGIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () {
                      openPage(
                        context,
                        const PatientLoginScreen(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() =>
      _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final TextEditingController _phoneController =
  TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendLoginCode() async {
    final phone = _phoneController.text.trim();

    if (!phone.startsWith('+') || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your registered phone number, e.g. +27...',
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

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            final result = await FirebaseAuth.instance
                .signInWithCredential(credential);

            final user = result.user;

            if (user == null) {
              throw Exception('Login could not be completed.');
            }

            await _openPatientDashboard(user.uid);
          } catch (e) {
            if (!mounted) return;

            setState(() => _loading = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: $e')),
            );
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() => _loading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ?? 'Phone verification failed.',
              ),
            ),
          );
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() => _loading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientLoginVerificationScreen(
                verificationId: verificationId,
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openPatientDashboard(String uid) async {
    final patient = await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .get();

    if (!patient.exists) {
      await FirebaseAuth.instance.signOut();
      throw Exception('No registered patient profile found.');
    }

    await savePatientFcmToken();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const PatientDashboardScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.login,
                  color: Colors.teal,
                  size: 75,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Existing Patient Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter the phone number you used when registering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Registered phone number',
                    hintText: '+27...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loading ? null : _sendLoginCode,
                    child: _loading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text('SEND LOGIN CODE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class PatientLoginVerificationScreen extends StatefulWidget {
  final String verificationId;

  const PatientLoginVerificationScreen({
    super.key,
    required this.verificationId,
  });

  @override
  State<PatientLoginVerificationScreen> createState() =>
      _PatientLoginVerificationScreenState();
}

class _PatientLoginVerificationScreenState
    extends State<PatientLoginVerificationScreen> {
  final TextEditingController _codeController =
  TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyLoginCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the SMS verification code.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = result.user;

      if (user == null) {
        throw Exception('Unable to sign in.');
      }

      final patient = await FirebaseFirestore.instance
          .collection('patients')
          .doc(user.uid)
          .get();

      if (!patient.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception(
          'No patient account is registered with this phone number.',
        );
      }

      await savePatientFcmToken();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientDashboardScreen(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Incorrect verification code.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Patient Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sms,
                  color: Colors.teal,
                  size: 70,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Patient Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Enter the SMS code sent to your registered phone number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'SMS verification code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                    _loading ? null : _verifyLoginCode,
                    child: _loading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text('VERIFY AND LOGIN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patient Dashboard'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: MediReadyPatientBackground(
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const PatientRegistrationScreen(),
                  ),
                );
              },
              child: const Text('REGISTER FIRST'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

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
      body: MediReadyPatientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to your dashboard',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your medications and daily reminders.',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 25),

              Card(
                color: Colors.white.withOpacity(0.92),
                child: ListTile(
                  leading: const Icon(
                    Icons.medication,
                    color: Colors.teal,
                    size: 35,
                  ),
                  title: const Text('My Medications'),
                  subtitle: const Text(
                    'View your medication collection status.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    openPage(
                      context,
                      const MedicationsScreen(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Card(
                color: Colors.white.withOpacity(0.92),
                child: ListTile(
                  leading: const Icon(
                    Icons.alarm,
                    color: Colors.orange,
                    size: 35,
                  ),
                  title: const Text('Medication Reminders'),
                  subtitle: const Text(
                    'Set and manage daily medication reminders.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    openPage(
                      context,
                      const MedicationReminderScreen(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Card(
                color: Colors.white.withOpacity(0.92),
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.deepOrange,
                    size: 35,
                  ),
                  title: const Text('Notifications'),
                  subtitle: const Text(
                    'View updates from your pharmacy about your medication.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    openPage(
                      context,
                      const NotificationsScreen(),
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



class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends State<PatientRegistrationScreen> {
  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _idController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerPatient() async {
    final String name = _nameController.text.trim();
    final String idNumber = _idController.text.trim();
    final String phoneNumber = _phoneController.text.trim();

    if (name.isEmpty || idNumber.isEmpty || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields.'),
        ),
      );
      return;
    }

    if (!phoneNumber.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your phone number with country code, e.g. +27.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(
              credential,
            );
          } catch (e) {
            debugPrint(
              'Automatic phone verification error: $e',
            );
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            _loading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ?? 'Phone verification failed.',
              ),
            ),
          );
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _loading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SmsVerificationScreen(
                verificationId: verificationId,
                name: name,
                idNumber: idNumber,
                phoneNumber: phoneNumber,
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('SMS code retrieval timed out.');
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registration'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.person_add_alt_1,
                  size: 75,
                  color: Colors.teal,
                ),

                const SizedBox(height: 15),

                const Text(
                  'Create Your Patient Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Register with MediReady to manage your medication collection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 25),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'ID number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Phone number',
                    hintText: '+27...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loading
                        ? null
                        : _registerPatient,
                    icon: const Icon(Icons.verified_user),
                    label: _loading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text(
                      'REGISTER AND VERIFY PHONE',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// SMS VERIFICATION SCREEN

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
  final _smsController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final smsCode = _smsController.text.trim();

    if (smsCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the SMS code.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        throw Exception('Patient account could not be created.');
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RegistrationSuccessScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'SMS verification failed.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Verification'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.sms,
              size: 70,
              color: Colors.teal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter the verification code sent to your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _smsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'SMS verification code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('VERIFY PHONE NUMBER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// REGISTRATION SUCCESS SCREEN

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Complete'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 90,
              ),
              const SizedBox(height: 20),
              const Text(
                'Registration Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your MediReady patient account has been created.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                          (route) => false,
                    );
                  },
                  child: const Text('RETURN TO HOME'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// PATIENT MEDICATIONS SCREEN


class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'collected':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  double statusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
        return 0.33;
      case 'ready':
        return 0.66;
      case 'collected':
        return 1.0;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: MediReadyPatientBackground(
          child: const Center(
            child: Text(
              'Please sign in to view your medications.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('medications')
              .where('patientId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load medications.'),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No medications found.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Your Medication Collection',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Track your medication preparation and collection progress.',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 18),

                ...medications.map((medication) {
                  final data =
                  medication.data() as Map<String, dynamic>;

                  final medicationName =
                      data['medicationName']?.toString() ??
                          'Medication';

                  final pharmacyName =
                      data['pharmacyName']?.toString() ??
                          'Unknown pharmacy';

                  final status =
                      data['status']?.toString() ?? 'Pending';

                  final color = statusColor(status);
                  final progress = statusProgress(status);

                  return Card(
                    color: Colors.white.withOpacity(0.93),
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.medication,
                                color: Colors.teal,
                                size: 35,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  medicationName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Pharmacy: $pharmacyName',
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Collection progress',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade300,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const Text(
                                'Current status:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            status.toLowerCase() == 'ready'
                                ? 'Your medication is ready for collection!'
                                : status.toLowerCase() == 'collected'
                                ? 'Your medication has been collected.'
                                : status.toLowerCase() ==
                                'preparing'
                                ? 'The pharmacy is preparing your medication.'
                                : 'Your medication is awaiting preparation.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}


class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key});

  @override
  State<MedicationReminderScreen> createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState
    extends State<MedicationReminderScreen> {
  final TextEditingController medicationController =
  TextEditingController();

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  TimeOfDay selectedTime =
  const TimeOfDay(hour: 8, minute: 0);

  bool saving = false;

  Future<void> chooseTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<void> scheduleReminder() async {
    final medication = medicationController.text.trim();

    if (medication.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a medication name.'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Please sign in before saving a reminder.',
        );
      }

      final now = tz.TZDateTime.now(tz.local);

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(
          const Duration(days: 1),
        );
      }

      await notifications.zonedSchedule(
        id: medication.hashCode,
        title: 'MediReady Medication Reminder',
        body: 'Time to take $medication',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mediready_daily_reminders',
            'Daily Medication Reminders',
            channelDescription:
            'Daily reminders to take medication',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode:
        AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      await FirebaseFirestore.instance
          .collection('medicationReminders')
          .add({
        'patientId': user.uid,
        'medicationName': medication,
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
        'createdAt': FieldValue.serverTimestamp(),
        'enabled': true,
      });

      medicationController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily reminder set and saved for $medication.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not set reminder: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    medicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.alarm,
                size: 65,
                color: Colors.teal,
              ),
              const SizedBox(height: 15),
              const Text(
                'Set a Medication Reminder',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a medication and the time you need '
                    'to take it. MediReady will remind you daily.',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 25),

              TextField(
                controller: medicationController,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Medication name',
                  hintText: 'Example: Blood pressure medication',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                color: Colors.white.withOpacity(0.93),
                child: ListTile(
                  leading: const Icon(
                    Icons.access_time,
                    color: Colors.teal,
                  ),
                  title: const Text('Reminder time'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.edit),
                  onTap: chooseTime,
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : scheduleReminder,
                  icon: const Icon(Icons.notifications_active),
                  label: Text(
                    saving
                        ? 'Setting reminder...'
                        : 'Set Daily Reminder',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// PATIENT PHARMACY NOTIFICATIONS

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    }

    return 'Date not available';
  }

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

  Future<void> _markAsRead(
      BuildContext context,
      DocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();

    if (data == null || data['isRead'] == true) return;

    try {
      await document.reference.update({'isRead': true});
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'You do not have permission to update this notification.'
                : 'Could not mark notification as read: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyPatientBackground(
        child: user == null
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in to view your pharmacy notifications.',
              textAlign: TextAlign.center,
            ),
          ),
        )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('patientId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load notifications. Please check your '
                        'internet connection and Firestore permissions.',
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

            final documents =
            List<DocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data?.docs ?? [],
            );

            documents.sort((a, b) {
              final aValue = a.data()?['createdAt'];
              final bValue = b.data()?['createdAt'];

              final aDate = aValue is Timestamp
                  ? aValue.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              final bDate = bValue is Timestamp
                  ? bValue.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              return bDate.compareTo(aDate);
            });

            if (documents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 76,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pharmacy updates about your medications '
                            'will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final unreadCount = documents.where((document) {
              return document.data()?['isRead'] != true;
            }).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  unreadCount == 0
                      ? 'You are all caught up.'
                      : '$unreadCount unread '
                      '${unreadCount == 1 ? 'notification' : 'notifications'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 12),

                ...documents.map((document) {
                  final data =
                      document.data() ?? <String, dynamic>{};

                  final title =
                      data['title']?.toString() ??
                          'Medication update';

                  final message =
                      data['message']?.toString() ??
                          'Your pharmacy has updated your medication.';

                  final medicationName =
                      data['medicationName']?.toString() ??
                          'Medication';

                  final pharmacyName =
                      data['pharmacyName']?.toString() ??
                          'Pharmacy';

                  final status =
                      data['status']?.toString() ?? 'Update';

                  final isRead = data['isRead'] == true;
                  final statusColor = _statusColor(status);

                  return Card(
                    color: Colors.white.withOpacity(0.94),
                    elevation: isRead ? 1 : 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          _markAsRead(context, document),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notifications_active,
                                  color: isRead
                                      ? Colors.grey
                                      : Colors.deepOrange,
                                  size: 27,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade50,
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.deepOrange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(message),

                            const SizedBox(height: 12),

                            Text(
                              'Medication: $medicationName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text('Pharmacy: $pharmacyName'),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius:
                                    BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    _formatDate(data['createdAt']),
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (!isRead) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Tap this notification to mark it as read.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}


// ==========================================
// MEDIREADY BLURRED CAPSULE BACKGROUND
// ==========================================

class MediReadyBackground extends StatelessWidget {
  final Widget child;

  const MediReadyBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 5,
            sigmaY: 5,
          ),
          child: Image.asset(
            'assets/images/mediready_background.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.teal.shade50,
              );
            },
          ),
        ),

        Container(
          color: Colors.white.withOpacity(0.78),
        ),

        child,
      ],
    );
  }
}

// ==========================================
// ABOUT MEDIREADY
// ==========================================

class AboutMediReadyScreen extends StatelessWidget {
  const AboutMediReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About MediReady'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              SizedBox(height: 25),
              Icon(
                Icons.medical_services,
                size: 85,
                color: Colors.teal,
              ),
              SizedBox(height: 20),
              Text(
                'About MediReady',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'MediReady is a medication management '
                    'application designed to make medication '
                    'collection and reminders easier.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
              SizedBox(height: 18),
              Text(
                'Our goal is to help patients stay informed '
                    'about their medication collection status, '
                    'manage medication reminders and receive '
                    'important pharmacy updates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HELP AND SUPPORT
// ==========================================

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help and Support'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Icon(
              Icons.support_agent,
              size: 75,
              color: Colors.teal,
            ),
            SizedBox(height: 20),
            Text(
              'How can we help you?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            SizedBox(height: 25),
            Card(
              child: ListTile(
                leading: Icon(Icons.person, color: Colors.teal),
                title: Text('Patient Registration'),
                subtitle: Text(
                  'Use the Patient Portal to register and '
                      'verify your phone number.',
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.medication,
                  color: Colors.teal,
                ),
                title: Text('My Medications'),
                subtitle: Text(
                  'View your medication information through '
                      'your patient dashboard.',
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: Colors.teal,
                ),
                title: Text('Notifications and Reminders'),
                subtitle: Text(
                  'Check your notifications and set medication '
                      'reminders from your dashboard.',
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.local_pharmacy,
                  color: Colors.teal,
                ),
                title: Text('Pharmacy Updates'),
                subtitle: Text(
                  'Check your medication collection status '
                      'for pharmacy updates.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CONTACT PHARMACY
// ==========================================

class ContactPharmacyScreen extends StatelessWidget {
  const ContactPharmacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.contact_phone,
                size: 80,
                color: Colors.teal,
              ),
              SizedBox(height: 20),
              Text(
                'Contact the Pharmacy',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 25),
              Card(
                child: ListTile(
                  leading: Icon(Icons.phone, color: Colors.teal),
                  title: Text('Telephone'),
                  subtitle: Text('011 000 5230 / 072 159 7895'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.email, color: Colors.teal),
                  title: Text('Email'),
                  subtitle: Text('service@testpharmacy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PHARMACY LOCATION
// ==========================================

class PharmacyLocationScreen extends StatelessWidget {
  const PharmacyLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Location'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: MediReadyBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.location_on,
                size: 85,
                color: Colors.red,
              ),
              SizedBox(height: 20),
              Text(
                'Find Our Pharmacy',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.local_pharmacy,
                    color: Colors.teal,
                  ),
                  title: Text('Pharmacy Address'),
                  subtitle: Text(
                    'Corner of Searle and Pontac Street, PO Box 5142,Roodepoort 1724, South Africa',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class MediReadyPatientBackground extends StatelessWidget {
  final Widget child;

  const MediReadyPatientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 2.0,
            sigmaY: 2.0,
          ),
          child: Image.asset(
            'assets/images/patient_portal_background_pharmacy.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.teal.shade50);
            },
          ),
        ),
        Container(
          color: Colors.white.withOpacity(0.68),
        ),
        child,
      ],
    );
  }
}
