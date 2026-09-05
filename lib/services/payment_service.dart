import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Only import Stripe on non-web
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentService {
  static Future<bool> processPayment({
    required BuildContext context,
    required int amount,
    required String description,
  }) async {
    // ✅ Stripe doesn't work on web — show message and return false
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pagesat janë të disponueshme vetëm në aplikacion. / Payments are only available in the mobile app.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ));
      }
      return false;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await user.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPaymentIntent', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)));

      final result = await callable.call({'amount': amount, 'currency': 'eur', 'description': description});

      final data = Map<String, dynamic>.from(result.data as Map);
      final clientSecret = data['clientSecret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Urbane',
          billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(address: AddressCollectionMode.never),
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: Color(0xFF3A7DFF))),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Only update abone status for elderly post-approval payments
      if (description.contains('abone') || description.contains('Abone')) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final aboneQuery = await FirebaseFirestore.instance
              .collection('abonements')
              .where('user_id', isEqualTo: uid)
              .where('status', isEqualTo: 'approved_for_payment')
              .get();
          if (aboneQuery.docs.isNotEmpty) {
            final now = DateTime.now();
            final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            await aboneQuery.docs.first.reference.update({
              'status': 'active',
              'payment_status': 'paid',
              'paid_at': FieldValue.serverTimestamp(),
              'valid_from': Timestamp.fromDate(now),
              'valid_until': Timestamp.fromDate(endOfMonth),
            });
          }
        }
      }

      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      debugPrint('Stripe error: \${e.error.code} - \${e.error.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Stripe: \${e.error.message ?? e.error.code.toString()}'),
          backgroundColor: Colors.red, duration: const Duration(seconds: 6),
        ));
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase Functions error: \${e.code} - \${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Functions error: \${e.code} — \${e.message}'),
          backgroundColor: Colors.red, duration: const Duration(seconds: 8),
        ));
      }
      return false;
    } catch (e) {
      debugPrint('Payment error: \$e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: \${e.toString()}'),
          backgroundColor: Colors.red, duration: const Duration(seconds: 8),
        ));
      }
      return false;
    }
  }
}