/// External booking-link builders for trains and buses.
///
/// Honest links only: they point at the provider's own search page for the
/// requested route and open in the user's browser — Route2Go never books,
/// takes payment, or claims availability it hasn't checked.
class BookingLinks {
  BookingLinks._();

  /// redBus route search by city name. `fromCity` is optional (the user's
  /// current location may be unknown); `onDate` defaults to tomorrow.
  static String redBus({
    String? fromCity,
    required String toCity,
    DateTime? onDate,
  }) {
    final date = onDate ?? DateTime.now().add(const Duration(days: 1));
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final from = fromCity?.trim();
    const base = 'https://www.redbus.in/search';
    final q = from == null || from.isEmpty
        ? '?toCityName=${Uri.encodeComponent(toCity.trim())}'
        : '?fromCityName=${Uri.encodeComponent(from)}'
            '&toCityName=${Uri.encodeComponent(toCity.trim())}';
    return '$base$q&onward=$d';
  }

  /// IRCTC official train-search page (no reliable query-parameter deep link,
  /// so we open the search page and the user enters stations).
  static String irctcTrain() => 'https://www.irctc.co.in/nget/train-search';
}
