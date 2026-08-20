import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/domain/entities/hotel_details.dart';

void main() {
  group('HotelDetails.fromJson', () {
    test('parses a full listing', () {
      final d = HotelDetails.fromJson(const {
        'name': 'The Taj Mahal Palace, Mumbai',
        'photo_url': 'https://img.example/taj.jpg',
        'rating': 4.7,
        'review_count': 3200,
        'price_per_night': 18500,
        'booking_url': 'https://example.com/taj',
      });
      expect(d.name, 'The Taj Mahal Palace, Mumbai');
      expect(d.photoUrl, 'https://img.example/taj.jpg');
      expect(d.rating, 4.7);
      expect(d.reviewCount, 3200);
      expect(d.pricePerNight, 18500);
      expect(d.bookingUrl, 'https://example.com/taj');
    });

    test('keeps optional fields null when absent', () {
      final d = HotelDetails.fromJson(const {'name': 'ITC Gardenia'});
      expect(d.name, 'ITC Gardenia');
      expect(d.photoUrl, isNull);
      expect(d.rating, isNull);
      expect(d.reviewCount, isNull);
      expect(d.pricePerNight, isNull);
      expect(d.bookingUrl, isNull);
    });

    test('falls back to an empty name for malformed input', () {
      final d = HotelDetails.fromJson(const {});
      expect(d.name, '');
      expect(d.photoUrl, isNull);
    });
  });
}
