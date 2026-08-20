import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'DirectChatScreen.dart';
import 'AiAccessGateScreen.dart';
import 'ByokSettingsScreen.dart';
import 'AdminPanelScreen.dart';
import 'util/formatters.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: currentUser != null
          ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
          : null,
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final bool allowAi = userData['allowAi'] ?? false;
        final Map<String, dynamic> thirdParty = userData['thirdPartyAi'] ?? {};
        final bool byokUnlocked = thirdParty['byokUnlocked'] ?? false;
        final bool hasAiAccess = allowAi || byokUnlocked;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ks-messaging'),
            elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              )
            ],
          ),
          drawer: const AppDrawer(),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading users.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final otherUsers = docs.where((doc) => doc.id != currentUser?.uid).toList();

              if (otherUsers.isEmpty) {
                return const Center(child: Text('No other users found.'));
              }

              return ListView.builder(
                itemCount: otherUsers.length,
                itemBuilder: (context, index) {
                  final uData = otherUsers[index].data() as Map<String, dynamic>;
                  final peerUid = uData['uid'] ?? otherUsers[index].id;
                  final peerName = uData['displayName'] ?? 'User';
                  final peerEmail = uData['email'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(peerName.isNotEmpty ? peerName[0].toUpperCase() : 'U'),
                    ),
                    title: Text(peerName),
                    subtitle: Text(peerEmail),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DirectChatScreen(
                            peerUid: peerUid,
                            peerName: peerName,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: hasAiAccess
              ? FloatingActionButton.extended(
                  onPressed: () => _openGeminiChat(context),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Assistant'),
                  backgroundColor: Colors.indigo,
                )
              : null,
        );
      },
    );
  }

  static void _openGeminiChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Gemini Assistant'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: LlmChatView(
          provider: FirebaseProvider(
            model: FirebaseAI.googleAI().generativeModel(
              model: 'gemini-1.5-flash',
            ),
          ),
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _launchLegalHelp(BuildContext context) async {
    final Uri url = Uri.parse('https://ks-messaging-docs.ks-everything.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Legal & Help documentation.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _launchBriarHandoff(BuildContext context) async {
    final Uri briarAppUri = Uri.parse('market://details?id=org.briarproject.briar.android');
    final Uri briarWebUri = Uri.parse('https://play.google.com/store/apps/details?id=org.briarproject.briar.android');

    if (await canLaunchUrl(briarAppUri)) {
      await launchUrl(briarAppUri, mode: LaunchMode.externalApplication);
    } else if (!await launchUrl(briarWebUri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store for Briar.')),
        );
      }
    }
  }

  void _openGeminiChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Gemini Assistant'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: LlmChatView(
          provider: FirebaseProvider(
            model: FirebaseAI.googleAI().generativeModel(
              model: 'gemini-1.5-flash',
            ),
          ),
        ),
      ),
    );
  }

  void _handleAiAccess(BuildContext context, Map<String, dynamic> userData) {
    Navigator.pop(context);

    final bool allowAi = userData['allowAi'] ?? false;
    final Map<String, dynamic> thirdParty = userData['thirdPartyAi'] ?? {};
    final bool byokUnlocked = thirdParty['byokUnlocked'] ?? false;
    final bool hasCustomKey = thirdParty['hasCustomKey'] ?? false;

    if (allowAi) {
      _openGeminiChat(context);
    } else if (byokUnlocked) {
      if (hasCustomKey) {
        _openGeminiChat(context);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ByokSettingsScreen()),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiAccessGateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid;
    final bool isAdmin = currentUser?.email == 'kfunallday@kssearchengine.com';

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: currentUid != null
            ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
            : null,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blueAccent),
                child: Center(
                  child: Image.asset(
                    'assets/icon/logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.shield, size: 60, color: Colors.white),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.indigo),
                title: const Text('AI Assistant'),
                subtitle: Text(
                  (userData['allowAi'] ?? false) || (userData['thirdPartyAi']?['byokUnlocked'] ?? false)
                      ? 'Ask AI anything'
                      : 'Access Gateway',
                ),
                onTap: () => _handleAiAccess(context, userData),
              ),
              ListTile(
                leading: const Icon(Icons.key, color: Colors.teal),
                title: const Text('BYOK Keys'),
                subtitle: const Text('Custom Developer Keys'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ByokSettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: const Text('Briar Handoff'),
                subtitle: const Text('Mesh / Offline Handoff'),
                trailing: const Chip(
                  label: Text('Secure Mode',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.green,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _launchBriarHandoff(context);
                },
              ),
              if (isAdmin) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.deepOrange),
                  title: const Text('Admin Control Panel'),
                  subtitle: const Text('Manage Quotas & AI Permissions'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                    );
                  },
                ),
              ],
              const Spacer(),
              Builder(
                builder: (context) {
                  final int bytesUsed = userData['bytesUsed'] ?? 0;
                  final int storageQuotaBytes = userData['storageQuotaBytes'] ?? 262144000;

                  final double percent = storageQuotaBytes > 0
                      ? (bytesUsed / storageQuotaBytes) * 100
                      : 0.0;
                  final double progressRatio = storageQuotaBytes > 0
                      ? (bytesUsed / storageQuotaBytes).clamp(0.0, 1.0)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${formatBytes(bytesUsed)} / ${formatBytes(storageQuotaBytes)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progressRatio,
                          backgroundColor: Colors.grey[300],
                          color: progressRatio > 0.9 ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Decoupled Cloud & Local Device Storage Active',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => _launchLegalHelp(context),
                          child: const Text(
                            'Legal & Help',
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}