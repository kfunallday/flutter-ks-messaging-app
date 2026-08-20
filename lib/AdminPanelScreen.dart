import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'util/formatters.dart';

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
            icon: const Icon(Icons.psychology),
            tooltip: 'Manage AI Models',
            onPressed: _showModelManagementDialog,
          ),
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
              final int quotaBytes = data['storageQuotaBytes'] ?? 262144000;
              final bool hasByokAccess = data['hasByokAccess'] ?? false;
              final bool hasAiAccess = data['hasAiAccess'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email line
                      SelectableText(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // UID on separate line with wrap/auto-adjust
                      SelectableText(
                        'UID: $uid',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Storage Usage Meter
                      Text(
                        'Storage: ${formatBytes(bytesUsed)} / ${formatBytes(quotaBytes)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: bytesUsed >= quotaBytes ? Colors.red : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: quotaBytes > 0 ? (bytesUsed / quotaBytes).clamp(0.0, 1.0) : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: bytesUsed >= quotaBytes ? Colors.red : Colors.blue,
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
                            onPressed: () => _showQuotaDialog(uid, quotaBytes),
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
          const SnackBar(content: Text('Storage usage reset to 0 B.')),
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

  void _showQuotaDialog(String uid, int currentQuotaBytes) {
    final controller = TextEditingController();
    String selectedUnit = 'MB';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust Storage Quota'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: selectedUnit,
                items: ['KB', 'MB', 'GB', 'TB']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedUnit = val);
                },
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? val = double.tryParse(controller.text.trim());
                if (val != null && val >= 0) {
                  final int newBytes = parseToBytes(val, selectedUnit);
                  await _updateUserField(uid, 'storageQuotaBytes', newBytes);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelManagementDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Available AI Models'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Model Identifier',
            hintText: 'gemini-1.5-pro',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestore.collection('config').doc('ai_models').set({
                  'availableModels': FieldValue.arrayUnion([controller.text.trim()])
                }, SetOptions(merge: true));
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add Model'),
          ),
        ],
      ),
    );
  }
}