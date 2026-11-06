/// Distances as the user logged them, and the one place kilometres and miles are converted.
library;

enum DistanceUnit { km, mile }

/// A logged distance, kept in the unit it was entered in: never converted when saved.
class Distance {
  const Distance(this.value, this.unit);

  /// Whole kilometres or miles.
  final int value;
  final DistanceUnit unit;
}

/// The total of [distances] in [unit], in whole units. Each unit is added up first, then the other unit's total is
/// converted once (1 mile = 1.609344 km exactly) and rounded half up, so many short trips don't pile up rounding.
int totalIn(DistanceUnit unit, Iterable<Distance> distances) {
  var same = 0;
  var other = 0;
  for (final d in distances) {
    if (d.unit == unit) {
      same += d.value;
    } else {
      other += d.value;
    }
  }
  // Integer arithmetic, so the conversion is exact before its one rounding: km = miles × 1609344 / 10^6.
  final (numerator, denominator) = unit == DistanceUnit.km ? (other * 1609344, 1000000) : (other * 1000000, 1609344);
  return same + (2 * numerator + denominator) ~/ (2 * denominator);
}
