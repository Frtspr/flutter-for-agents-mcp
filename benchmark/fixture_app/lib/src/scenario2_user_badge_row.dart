import 'package:flutter/material.dart';

class UserTransactionBadgeRow extends StatelessWidget {
  final String senderName;
  final String senderEmail;
  final String amount;
  final String timestamp;

  const UserTransactionBadgeRow({
    super.key,
    this.senderName = 'Alexander Montgomery-Smith',
    this.senderEmail =
        'alexander.montgomery-smith@longcorporateorganization-enterprise.internal.corp',
    this.amount = r'-$12,450.00 USD',
    this.timestamp = '2 mins ago',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      // HORROR: Row without Expanded on dynamic Text children
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal.shade700,
            radius: 20.0,
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 20.0),
          ),
          const SizedBox(width: 12.0),
          // Unconstrained dynamic title and email column in a Row!
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                senderName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
              const SizedBox(height: 2.0),
              Text(
                senderEmail,
                style: const TextStyle(color: Colors.grey, fontSize: 12.0),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 13.0),
              ),
              Text(
                timestamp,
                style: const TextStyle(color: Colors.grey, fontSize: 11.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
