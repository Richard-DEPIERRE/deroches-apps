// Barème kilométrique for 2024 income (déclaration 2025). Figures and source: DAPP-137's `rate-tables`.
import '../french_bareme.dart';

const bareme2024 = FrenchBareme(
  year: 2024,
  source: BaremeSource(
    title: 'BOI-BAREME-000001',
    url: 'https://bofip.impots.gouv.fr/bofip/2185-PGP.html',
    publishedOn: '2025-01-01',
  ),
  bands: bands2024,
);

/// Also 2025's: that year's text kept these figures.
const bands2024 = {
  VehicleType.car: [
    HorsepowerBand(
      minCv: 1,
      maxCv: 3,
      brackets: [
        Bracket(upToKm: 5000, ratePerKmMilli: 529),
        Bracket(upToKm: 20000, ratePerKmMilli: 316, fixedEuros: 1065),
        Bracket(upToKm: null, ratePerKmMilli: 370),
      ],
    ),
    HorsepowerBand(
      minCv: 4,
      maxCv: 4,
      brackets: [
        Bracket(upToKm: 5000, ratePerKmMilli: 606),
        Bracket(upToKm: 20000, ratePerKmMilli: 340, fixedEuros: 1330),
        Bracket(upToKm: null, ratePerKmMilli: 407),
      ],
    ),
    HorsepowerBand(
      minCv: 5,
      maxCv: 5,
      brackets: [
        Bracket(upToKm: 5000, ratePerKmMilli: 636),
        Bracket(upToKm: 20000, ratePerKmMilli: 357, fixedEuros: 1395),
        Bracket(upToKm: null, ratePerKmMilli: 427),
      ],
    ),
    HorsepowerBand(
      minCv: 6,
      maxCv: 6,
      brackets: [
        Bracket(upToKm: 5000, ratePerKmMilli: 665),
        Bracket(upToKm: 20000, ratePerKmMilli: 374, fixedEuros: 1457),
        Bracket(upToKm: null, ratePerKmMilli: 447),
      ],
    ),
    HorsepowerBand(
      minCv: 7,
      brackets: [
        Bracket(upToKm: 5000, ratePerKmMilli: 697),
        Bracket(upToKm: 20000, ratePerKmMilli: 394, fixedEuros: 1515),
        Bracket(upToKm: null, ratePerKmMilli: 470),
      ],
    ),
  ],
  VehicleType.motorbike: [
    HorsepowerBand(
      minCv: 1,
      maxCv: 2,
      brackets: [
        Bracket(upToKm: 3000, ratePerKmMilli: 395),
        Bracket(upToKm: 6000, ratePerKmMilli: 99, fixedEuros: 891),
        Bracket(upToKm: null, ratePerKmMilli: 248),
      ],
    ),
    HorsepowerBand(
      minCv: 3,
      maxCv: 5,
      brackets: [
        Bracket(upToKm: 3000, ratePerKmMilli: 468),
        Bracket(upToKm: 6000, ratePerKmMilli: 82, fixedEuros: 1158),
        Bracket(upToKm: null, ratePerKmMilli: 275),
      ],
    ),
    HorsepowerBand(
      minCv: 6,
      brackets: [
        Bracket(upToKm: 3000, ratePerKmMilli: 606),
        Bracket(upToKm: 6000, ratePerKmMilli: 79, fixedEuros: 1583),
        Bracket(upToKm: null, ratePerKmMilli: 343),
      ],
    ),
  ],
  VehicleType.moped: [
    HorsepowerBand(
      minCv: 1,
      brackets: [
        Bracket(upToKm: 3000, ratePerKmMilli: 315),
        Bracket(upToKm: 6000, ratePerKmMilli: 79, fixedEuros: 711),
        Bracket(upToKm: null, ratePerKmMilli: 198),
      ],
    ),
  ],
};
