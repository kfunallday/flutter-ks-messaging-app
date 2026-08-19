import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading user database.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No users found in database.'));
          }

          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final data = userDoc.data() as Map<String, dynamic>;
              
              final String uid = userDoc.id;
              final String email = data['email'] ?? 'No Email';
              final int bytesUsed = data['bytesUsed'] ?? 0;
              final int quotaBytes = data['storageQuotaBytes'] ?? 262144000; // 250 MB default
              final bool hasByokAccess = data['hasByokAccess'] ?? false;
              final bool hasAiAccess = data['hasAiAccess'] ?? false;

              final double usedMb = bytesUsed / (1024 * 1024);
              final double quotaMb = quotaBytes / (1024 * 1024);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.horizontal(8, 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'UID: ${uid.substring(0, uid.length > 8 ? 8 : uid.length)}...',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Storage Usage Meter
                      Text(
                        'Storage: ${usedMb.toStringAsFixed(1)} MB / ${quotaMb.toStringAsFixed(0)} MB',
                        style: TextStyle(
                          fontSize: 13,
                          color: usedMb >= quotaMb ? Colors.red : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: quotaMb > 0 ? (usedMb / quotaMb).clamp(0.0, 1.0) : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: usedMb >= quotaMb ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(height: 12),

                      // Feature Toggles
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('BYOK Access Granted'),
                        subtitle: const Text('Allow custom third-party API key usage'),
                        value: hasByokAccess,
                        onChanged: (val) => _updateUserField(uid, 'hasByokAccess', val),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AI Access Granted'),
                        subtitle: const Text('Allow hosted AI model interactions'),
                        value: hasAiAccess,
                        onChanged: (val) => _updateUserField(uid, 'hasAiAccess', val),
                      ),

                      const Divider(),
                      
                      // Quick Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.cleaning_services, size: 18),
                            label: const Text('Reset Usage'),
                            onPressed: () => _resetUserStorage(uid),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Set Quota'),
                            onPressed: () => _showQuotaDialog(uid, quotaMb),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateUserField(String uid, String field, dynamic value) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        field: value,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    }
  }

  Future<void> _resetUserStorage(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({'bytesUsed': 0});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage usage reset to 0 MB.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset storage: $e')),
        );
      }
    }
  }

  void _showQuotaDialog(String uid, double currentQuotaMb) {
    final controller = TextEditingController(text: currentQuotaMb.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Storage Quota'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quota in MB',
            suffixText: 'MB',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final double? newMb = double.tryParse(controller.text.trim());
              if (newMb != null && newMb >= 0) {
                final int newBytes = (newMb * 1024 * 1024).toInt();
                await _updateUserField(uid, 'storageQuotaBytes', newBytes);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}