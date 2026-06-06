import 'package:flutter_test/flutter_test.dart';
import 'package:upi_payment_alert/providers/payment_provider.dart';

void main() {
  test('Test parsePayment with various formats', () {
    // 1. Groww format (plain number, no prefix)
    final res1 = parsePayment('1.00 was credited to your account');
    expect(res1, isNotNull);
    expect(res1!.amount, 1.0);
    expect(res1.type, 'incoming');

    // 2. Groww format (debited)
    final res2 = parsePayment('123.45 was debited from Karan Patel');
    expect(res2, isNotNull);
    expect(res2!.amount, 123.45);
    expect(res2.type, 'outgoing');

    // 3. Paytm format
    final res3 = parsePayment('Paytm: Credited Rs.1200 from Karan Patel.');
    expect(res3, isNotNull);
    expect(res3!.amount, 1200.0);
    expect(res3.type, 'incoming');

    // 4. BHIM format
    final res4 = parsePayment('BHIM: ₹45.00 credited from Vijay Singh.');
    expect(res4, isNotNull);
    expect(res4!.amount, 45.0);
    expect(res4.type, 'incoming');

    // 5. Invalid notification (no keywords)
    final res5 = parsePayment('Just a random message with 100 Rs');
    expect(res5, isNull);

    // INCOMING patterns:
    // - "Rs.200 credited to a/c" (Indian Bank, SBI)
    final inc1 = parsePayment("Rs.200 credited to a/c");
    expect(inc1, isNotNull);
    expect(inc1!.amount, 200.0);
    expect(inc1.type, 'incoming');

    // - "Rs. 200 credited" (with space after Rs.)
    final inc2 = parsePayment("Rs. 200 credited");
    expect(inc2, isNotNull);
    expect(inc2!.amount, 200.0);
    expect(inc2.type, 'incoming');

    // - "INR 200 credited"
    final inc3 = parsePayment("INR 200 credited");
    expect(inc3, isNotNull);
    expect(inc3!.amount, 200.0);
    expect(inc3.type, 'incoming');

    // - "200 was credited to" (Groww)
    final inc4 = parsePayment("200 was credited to");
    expect(inc4, isNotNull);
    expect(inc4!.amount, 200.0);
    expect(inc4.type, 'incoming');

    // - "credited Rs.200"
    final inc5 = parsePayment("credited Rs.200");
    expect(inc5, isNotNull);
    expect(inc5!.amount, 200.0);
    expect(inc5.type, 'incoming');

    // - "received Rs.200"
    final inc6 = parsePayment("received Rs.200");
    expect(inc6, isNotNull);
    expect(inc6!.amount, 200.0);
    expect(inc6.type, 'incoming');

    // - "₹200 credited"
    final inc7 = parsePayment("₹200 credited");
    expect(inc7, isNotNull);
    expect(inc7!.amount, 200.0);
    expect(inc7.type, 'incoming');

    // OUTGOING patterns:
    // - "A/c debited Rs.200" (Indian Bank)
    final out1 = parsePayment("A/c debited Rs.200");
    expect(out1, isNotNull);
    expect(out1!.amount, 200.0);
    expect(out1.type, 'outgoing');

    // - "Rs.200 debited"
    final out2 = parsePayment("Rs.200 debited");
    expect(out2, isNotNull);
    expect(out2!.amount, 200.0);
    expect(out2.type, 'outgoing');

    // - "debited Rs. 200"
    final out3 = parsePayment("debited Rs. 200");
    expect(out3, isNotNull);
    expect(out3!.amount, 200.0);
    expect(out3.type, 'outgoing');

    // - "200 was debited from" (Groww format at start)
    final out4 = parsePayment("200 was debited from");
    expect(out4, isNotNull);
    expect(out4!.amount, 200.0);
    expect(out4.type, 'outgoing');

    // - "paid Rs.200"
    final out5 = parsePayment("paid Rs.200");
    expect(out5, isNotNull);
    expect(out5!.amount, 200.0);
    expect(out5.type, 'outgoing');

    // - "sent Rs.200"
    final out6 = parsePayment("sent Rs.200");
    expect(out6, isNotNull);
    expect(out6!.amount, 200.0);
    expect(out6.type, 'outgoing');

    // - "transferred Rs.200"
    final out7 = parsePayment("transferred Rs.200");
    expect(out7, isNotNull);
    expect(out7!.amount, 200.0);
    expect(out7.type, 'outgoing');

    // - "linked to VPA" with amount before it (Groww outgoing)
    // Example: "Rs.200 linked to VPA"
    final out8 = parsePayment("Rs. 200 linked to VPA");
    expect(out8, isNotNull);
    expect(out8!.amount, 200.0);
    expect(out8.type, 'outgoing');

    final out9 = parsePayment("₹200 linked to VPA");
    expect(out9, isNotNull);
    expect(out9!.amount, 200.0);
    expect(out9.type, 'outgoing');

    // Account number edge case tests
    final acctTest1 = parsePayment("A/c *6735 debited Rs. 1.00 on 06-06-26 to Mrs G DHANAL");
    expect(acctTest1, isNotNull);
    expect(acctTest1!.amount, 1.0);
    expect(acctTest1.type, 'outgoing');

    final acctTest2 = parsePayment("1.00 was credited to INDIAN BANK A/C XXXX6735");
    expect(acctTest2, isNotNull);
    expect(acctTest2!.amount, 1.0);
    expect(acctTest2.type, 'incoming');

    // Should not match standalone numbers that are not at the start and have no currency prefix
    final invalidAcct = parsePayment("Debited account *6735 directly");
    expect(invalidAcct, isNull);
  });
}

