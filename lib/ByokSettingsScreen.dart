import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ByokSettingsScreen extends StatefulWidget {
  const ByokSettingsScreen({super.key});

  @override
  State<ByokSettingsScreen> createState() => _ByokSettingsScreenState();
}

class _ByokSettingsScreenState extends State<ByokSettingsScreen> {
  final _keyController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  String _selectedProvider = 'OpenAI';
  bool _isLoading = false;
  bool _hasSavedKey = false;

  final List<String> _providers = [
    'OpenAI',
    'Anthropic',
    'Groq',
    'Gemini (BYOK)',
    'OpenRouter',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  // Reads key strictly from local device encrypted storage
  Future<void> _loadExistingKey() async {
    setState(() => _isLoading = true);
    final savedKey = await _storage.read(key: 'byok_key_$_selectedProvider');
    if (mounted) {
      setState(() {
        if (savedKey != null && savedKey.isNotEmpty) {
          _keyController.text = savedKey;
          _hasSavedKey = true;
        } else {
          _keyController.clear();
          _hasSavedKey = false;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveKey() async {
    final keyText = _keyController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;
    if (keyText.isEmpty) {
      _showSnackBar('Please enter a valid API key.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Store key in phone's hardware-encrypted vault (never touches Firestore)
      await _storage.write(
        key: 'byok_key_$_selectedProvider',
        value: keyText,
      );

      // 2. Update Firestore metadata flag only
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'thirdPartyAi': {
          'hasCustomKey': true,
          'activeProvider': _selectedProvider,
        }
      }, SetOptions(merge: true));

      setState(() {
        _hasSavedKey = true;
        _isLoading = false;
      });

      _showSnackBar('$_selectedProvider API key saved securely on device!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save key: $e');
    }
  }

  Future<void> _deleteKey() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      // Clear key locally
      await _storage.delete(key: 'byok_key_$_selectedProvider');
      _keyController.clear();

      // Clear metadata flag
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'thirdPartyAi': {
          'hasCustomKey': false,
          'activeProvider': '',
        }
      }, SetOptions(merge: true));

      setState(() {
        _hasSavedKey = false;
        _isLoading = false;
      });

      _showSnackBar('API key removed from device.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to remove key: $e');
    }
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BYOK - Custom Keys'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bring Your Own Key',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your API key is encrypted and stored strictly on this device. It is never uploaded to the cloud database.',
                    style: TextStyle(color: Colors.grey, height: 1.3),
                  ),
                  const SizedBox(height: 24),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Select AI Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: _providers.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedProvider = val);
                        _loadExistingKey();
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Enter $_selectedProvider API Key',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: Icon(
                        _hasSavedKey ? Icons.check_circle : Icons.key,
                        color: _hasSavedKey ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save Encrypted Key'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saveKey,
                        ),
                      ),
                      if (_hasSavedKey) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          tooltip: 'Remove Key',
                          onPressed: _deleteKey,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}