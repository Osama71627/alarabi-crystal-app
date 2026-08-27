import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/offer.dart';
import '../../domain/repositories/offer_repository.dart';

/// مستودع عروض عبر Firestore
/// يعود للبيانات التجريبية إن كانت قاعدة البيانات فارغة أو تعذر الاتصال
class FirestoreOfferRepository implements OfferRepository {
  FirestoreOfferRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection('offers');

  Future<List<Offer>> _fetchAll() async {
    try {
      final snapshot = await _offers.get();
      if (snapshot.docs.isEmpty) return DemoData.offers;
      return snapshot.docs
          .map((doc) => Offer.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return DemoData.offers;
    }
  }

  @override
  Future<List<Offer>> getActiveOffers() async {
    final offers = await _fetchAll();
    final now = DateTime.now();
    return offers
        .where((o) => o.isActive && (o.endDate?.isAfter(now) ?? true))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  Future<List<Offer>> getAllOffers() => _fetchAll();

  @override
  Stream<List<Offer>> watchOffers() {
    return _offers.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return DemoData.offers;
      return snapshot.docs
          .map((doc) => Offer.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> addOffer(Offer offer) {
    return _offers.doc(offer.id).set(_sanitize(offer.toMap()));
  }

  @override
  Future<void> updateOffer(Offer offer) {
    return _offers.doc(offer.id).set(_sanitize(offer.toMap()));
  }

  @override
  Future<void> deleteOffer(String id) {
    return _offers.doc(id).delete();
  }

  /// إزالة القيم الفارغة (Firestore لا يقبل null)
  Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        result[key] = _sanitize(value);
      } else if (value is Map) {
        result[key] = _sanitize(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
