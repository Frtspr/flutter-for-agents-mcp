import 'package:flutter/material.dart';

class WorkspaceSyncStatusCard extends StatelessWidget {
  final bool isSyncing;
  final String statusText;
  final VoidCallback? onRetry;

  const WorkspaceSyncStatusCard({
    super.key,
    required this.isSyncing,
    this.statusText = 'Synchronizing workspace models with remote cloud...',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (isSyncing)
              // HORROR: Indeterminate animation continuously schedules frames
              const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              const Icon(Icons.cloud_done, color: Colors.green, size: 24.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                statusText,
                style: const TextStyle(
                    fontSize: 13.0, fontWeight: FontWeight.w500),
              ),
            ),
            if (!isSyncing && onRetry != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}
