import 'package:flutter/material.dart';

class AiAccessGateScreen extends StatelessWidget {
  const AiAccessGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Access Gateway'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 70, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'Want AI Access?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'Contact me at kfunallday@kssearchengine.com',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Option 1: Developer BYOK Pass ($1 One-Time Fee)
            _buildOptionCard(
              title: 'Are you a developer?',
              description:
                  'We offer a one-time fee of \$1 for unlocking BYOK (Bring Your Own Key) instead of the subscription for access to our models. Just contact me and we\'ll work it out.',
              icon: Icons.code,
              color: Colors.teal.shade50,
            ),
            const SizedBox(height: 16),

            // Option 2: Hybrid Custom Solution
            _buildOptionCard(
              title: 'Developer Hybrid Access',
              description:
                  'Are you a developer interested in both BYOK and access to our models? Contact me and we can come up with a custom solution.',
              icon: Icons.build_circle_outlined,
              color: Colors.amber.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}