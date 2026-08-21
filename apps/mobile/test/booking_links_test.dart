import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/core/config/booking_links.dart';

void main() {
  group('BookingLinks.redBus', () {
    test('builds a from/to search URL with a fixed onward date', () {
      final url = BookingLinks.redBus(
        fromCity: 'Bengaluru',
        toCity: 'Mysuru',
        onDate: DateTime(2026, 8, 21),
      );
      expect(url, startsWith('https://www.redbus.in/search?'));
      expect(url, contains('fromCityName=Bengaluru'));
      expect(url, contains('toCityName=Mysuru'));
      expect(url, contains('onward=2026-08-21'));
    });

    test('omits fromCityName when the origin is unknown', () {
      final url = BookingLinks.redBus(
        toCity: 'Bengaluru',
        onDate: DateTime(2026, 8, 21),
      );
      expect(url, isNot(contains('fromCityName')));
      expect(url, contains('toCityName=Bengaluru'));
      expect(url, contains('onward=2026-08-21'));
    });

    test('URL-encodes city names with spaces', () {
      final url = BookingLinks.redBus(
        fromCity: 'New Delhi',
        toCity: 'Agra',
        onDate: DateTime(2026, 8, 21),
      );
      expect(url, contains('fromCityName=New%20Delhi'));
      expect(url, contains('toCityName=Agra'));
    });

    test('defaults the date to tomorrow', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final url = BookingLinks.redBus(toCity: 'Mysuru');
      final expected = '${tomorrow.year.toString().padLeft(4, '0')}-'
          '${tomorrow.month.toString().padLeft(2, '0')}-'
          '${tomorrow.day.toString().padLeft(2, '0')}';
      expect(url, contains('onward=$expected'));
    });
  });

  group('BookingLinks.irctcTrain', () {
    test('points at the official IRCTC train search page', () {
      expect(
        BookingLinks.irctcTrain(),
        'https://www.irctc.co.in/nget/train-search',
      );
    });
  });

  group('BookingLinks.flights', () {
    test('builds a flights query with destination and currency', () {
      final url = BookingLinks.flights(
        fromCity: 'Delhi',
        toCity: 'Mumbai',
        onDate: DateTime(2026, 8, 21),
      );
      expect(url, startsWith('https://www.google.com/travel/flights?'));
      expect(url, contains('q=flights%20from%20Delhi%20to%20Mumbai'));
      expect(url, contains('curr=INR'));
    });

    test('omits origin when unknown and encodes spaces', () {
      final url = BookingLinks.flights(toCity: 'New Delhi');
      expect(url, isNot(contains('from%20')));
      expect(url, contains('to%20New%20Delhi'));
    });
  });
}
