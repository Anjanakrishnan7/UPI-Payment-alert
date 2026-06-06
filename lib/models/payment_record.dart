import 'dart:convert';

class PaymentRecord {
  final double amount;
  final String sender;
  final String appName;
  final DateTime timestamp;
  final String rawText;
  final String packageName;
  final String title;
  final String body;
  final bool isSent;
  final String? accountNumber;

  PaymentRecord({
    required this.amount,
    required this.sender,
    required this.appName,
    required this.timestamp,
    required this.rawText,
    required this.packageName,
    required this.title,
    required this.body,
    this.isSent = false,
    this.accountNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'sender': sender,
      'appName': appName,
      'timestamp': timestamp.toIso8601String(),
      'rawText': rawText,
      'packageName': packageName,
      'title': title,
      'body': body,
      'isSent': isSent,
      'accountNumber': accountNumber,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      amount: (map['amount'] as num).toDouble(),
      sender: map['sender'] as String? ?? 'Unknown',
      appName: map['appName'] as String? ?? 'UPI App',
      timestamp: DateTime.parse(map['timestamp'] as String),
      rawText: map['rawText'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isSent: map['isSent'] as bool? ?? false,
      accountNumber: map['accountNumber'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory PaymentRecord.fromJson(String source) =>
      PaymentRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
