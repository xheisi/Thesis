import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  static Future<bool> processPayment({
    required BuildContext context,
    required int amount,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await user.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPaymentIntent',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 30)));

      final result = await callable.call({
        'amount': amount,
        'currency': 'eur',
        'description': description,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final clientSecret = data['clientSecret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Urbane',
          billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
            address: AddressCollectionMode.never,
          ),
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF3A7DFF)),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Only update abone status for elderly post-approval payments
      // (general abone and ticket payments don't need this)
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
      debugPrint('Stripe error: ${e.error.code} - ${e.error.message}');
      return false;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase Functions error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Payment error: $e');
      return false;
    }
  }
}