import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart'; // Import bcrypt package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// App Root
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firestore CRUD with Password',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UserPage(), // Set user page as home
    );
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  // Check if the entered password matches the hashed password stored in Firestore
  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) return;

    // Fetch user from Firestore by email
    final userQuery = await users.where('email', isEqualTo: email).get();
    if (userQuery.docs.isEmpty) {
      // User not found
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('User not found'),
      ));
      return;
    }

    final userDoc = userQuery.docs.first;
    final hashedPassword = userDoc['password'];

    try {
      // Verify password using bcrypt
      final isPasswordCorrect = BCrypt.checkpw(password, hashedPassword);

      if (isPasswordCorrect) {
        // Password matches, navigate to welcome page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomePage(name: userDoc['name']),
          ),
        );
      } else {
        // Incorrect password
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect password'),
        ));
      }
    } catch (e) {
      // Handle any exceptions related to bcrypt
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error verifying password: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email input
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            // Password input
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// Welcome Page
class WelcomePage extends StatelessWidget {
  final String name;
  const WelcomePage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Text(
          'Welcome, $name!', // Display user's name
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// User Page with CRUD
class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController(); // Password controller

  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  String? editingUserId;

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _ageController.clear();
    _passwordController.clear(); // Clear password field
    editingUserId = null;
  }

  // Hash the password before storing it
  String _hashPassword(String password) {
    final salt = BCrypt.gensalt(); // Generate salt
    return BCrypt.hashpw(password, salt); // Hash the password
  }

  // Add or Update
  Future<void> _saveUser() async {
    final name = _nameController.text;
    final email = _emailController.text;
    final age = int.tryParse(_ageController.text);
    final password = _passwordController.text; // Get password

    if (name.isEmpty || email.isEmpty || age == null || password.isEmpty)
      return;

    final hashedPassword = _hashPassword(password); // Hash password

    if (editingUserId == null) {
      // Add new user
      await users.add({
        'name': name,
        'email': email,
        'age': age,
        'password': hashedPassword, // Store hashed password
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Update user
      await users.doc(editingUserId).update({
        'name': name,
        'email': email,
        'age': age,
        'password': hashedPassword, // Update password (hashed)
      });
    }

    _clearFields();
  }

  // Delete
  Future<void> _deleteUser(String docId) async {
    await users.doc(docId).delete();
  }

  // Edit (load data into form)
  void _editUser(DocumentSnapshot doc) {
    _nameController.text = doc['name'];
    _emailController.text = doc['email'];
    _ageController.text = doc['age'].toString();
    _passwordController
        .clear(); // Do not load password into the form (for security)
    editingUserId = doc.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore User CRUD')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true, // Hide password input
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveUser,
              child: Text(editingUserId == null ? 'Add User' : 'Update User'),
            ),
            const SizedBox(height: 20),

            // User List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    users.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading users');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return ListTile(
                        title: Text(doc['name']),
                        subtitle: Text('${doc['email']} | Age: ${doc['age']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editUser(doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteUser(doc.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Button to go to Login Page
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
              child: const Text('Go to Login Page'),
            ),
          ],
        ),
      ),
    );
  }
}
