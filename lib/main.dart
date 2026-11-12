import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const mainBlack = Color(0xFF111111);
const goldColor = Color(0xFFFFD700);

bool firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    firebaseReady = true;
  } catch (e) {
    debugPrint("Firebase failed: $e");
    firebaseReady = false;
  }
  runApp(const ZXFFTourApp());
}

class ZXFFTourApp extends StatelessWidget {
  const ZXFFTourApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: mainBlack,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    // Firebase চালু না হলে আটকে থাকবে না, সরাসরি Login দেখাবে
    if (!firebaseReady) {
      return const LoginScreen(firebaseError: true);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const LoginScreen();
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: mainBlack,
            body: Center(child: CircularProgressIndicator(color: goldColor)),
          );
        }
        if (snap.hasData) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool firebaseError;
  const LoginScreen({super.key, this.firebaseError = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final ffCtrl = TextEditingController();
  bool isLogin = true;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainBlack,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              const Text("ZX", style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: goldColor)),
              const SizedBox(height: 10),
              if (widget.firebaseError)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.withOpacity(0.2),
                  child: const Text(
                    "Firebase Connect হয় নাই! নতুন google-services.json বসিয়ে আবার APK বানাও।",
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              if (!isLogin) TextField(controller: ffCtrl, decoration: const InputDecoration(labelText: "FF Name")),
              if (!isLogin) const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
              const SizedBox(height: 20),
              loading
                  ? const CircularProgressIndicator(color: goldColor)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: _auth, child: Text(isLogin ? "Login" : "Register")),
                    ),
              TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "Create Account" : "Already have account? Login")),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _auth() async {
    if (!firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Firebase চালু হয় নাই, নতুন APK বানাও")));
      return;
    }
    setState(() => loading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      } else {
        var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({'email': emailCtrl.text.trim(), 'ffName': ffCtrl.text.trim(), 'balance': 0});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => loading = false);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filter = "ALL";
  int tapCount = 0;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) setState(() => userData = doc.data());
    } catch (e) {
      debugPrint("loadUser error $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int balance = (userData?['balance'] ?? 0) as int;
    String ffName = (userData?['ffName'] ?? '') as String;
    return Scaffold(
      backgroundColor: mainBlack,
      appBar: AppBar(
        backgroundColor: mainBlack,
        title: GestureDetector(
          onTap: () {
            tapCount++;
            if (tapCount >= 5) { tapCount = 0; _adminLogin(context); }
          },
          child: Text("ZX FF TOUR - $ffName"),
        ),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ["ALL", "BR", "CS", "LW", "CUSTOM"].map((t) {
                bool a = filter == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(t), selected: a, onSelected: (_) => setState(() => filter = t)),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: goldColor));
                var rooms = snap.data!.docs.where((d) {
                  if (filter == "ALL") return true;
                  return (d['mode'] ?? '') == filter;
                }).toList();
                if (rooms.isEmpty) return const Center(child: Text("No rooms found"));
                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    var m = rooms[i].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text("\$${m['time']} | Slot: ${m['joinedSlot']}/${m['totalSlot']}"),
                        subtitle: Text("Room: ${m['roomId'] ?? ''}"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111122),
        selectedItemColor: goldColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => AddMoneyScreen(balance: balance, onRefresh: _loadUser)));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.diamond), label: "Topup"),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: "Results"),
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: "Play"),
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: "My Matches"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  void _adminLogin(BuildContext context) {
    TextEditingController p = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Admin Login"), content: TextField(controller: p, obscureText: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
}

class AddMoneyScreen extends StatefulWidget {
  final int balance;
  final VoidCallback onRefresh;
  const AddMoneyScreen({super.key, required this.balance, required this.onRefresh});
  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final amtCtrl = TextEditingController();
  String method = "Bkash";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainBlack,
      appBar: AppBar(title: const Text("Add Money")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Balance: ${widget.balance}", style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 20),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () { widget.onRefresh(); Navigator.pop(context); }, child: const Text("Request")),
          ],
        ),
      ),
    );
  }
}
