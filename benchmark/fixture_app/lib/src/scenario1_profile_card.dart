import 'package:flutter/material.dart';

class UserProfileCard extends StatelessWidget {
  final String username;
  final String email;
  final String bio;

  const UserProfileCard({
    super.key,
    this.username = 'alexander_turner',
    this.email = 'alexander.turner@enterprise-cloud.internal',
    this.bio = 'Principal Enterprise Architect & Systems Engineering Lead with over 15 years of distributed systems experience.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        // HORROR: Column without SingleChildScrollView or Expanded
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 54.0,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 54.0, color: Colors.white),
            ),
            const SizedBox(height: 16.0),
            Text(
              username,
              style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              email,
              style: const TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Text(
                'ENTERPRISE MEMBER',
                style: TextStyle(fontSize: 11.0, color: Colors.blueAccent, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20.0),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Biography & Overview',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              bio,
              style: const TextStyle(fontSize: 13.0, height: 1.4),
            ),
            const SizedBox(height: 24.0),
            TextFormField(
              initialValue: username,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              initialValue: 'https://github.com/alex-turner',
              decoration: const InputDecoration(
                labelText: 'Portfolio Website',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
