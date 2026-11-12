// Barème kilométrique for 2024 income (declared in 2025), as checked in DAPP-137's `rate-tables` (CE-FACT-CHECK PASS,
// read 2026-11-05):
// - Brochure pratique 2025, Déclaration des revenus 2024, p. 53 (DGFiP, PDF of 2025-03-20): every table below.
// - CGI annexe IV art. 6 B, in force since 2023-04-08 (Légifrance): paragraph I tables; paragraph II, +20% for
//   electric vehicles. https://www.legifrance.gouv.fr/codes/section_lc/LEGITEXT000006069576/LEGISCTA000028683322/
// - BOI-BAREME-000001-20230720 (BOFiP) § 5 (+20% since 2020 income) and § 15 (mopeds).
//
// A row per horsepower band, as published: Bracket(up to km, € per km in thousandths, fixed €).
import '../french_bareme.dart';

const bareme2024 = FrenchBareme(
  year: 2024,
  source: BaremeSource(
    title: 'Brochure pratique 2025, Déclaration des revenus 2024 (DGFiP)',
    url: 'https://www.impots.gouv.fr/www2/fichiers/documentation/brochure/ir_2025/pdf_integral/Brochure-IR-2025.pdf',
    publishedOn: '2025-03-20',
    readOn: '2026-11-05',
  ),
  bands: bands2024,
  electricBands: electricBands2024,
);

/// Thermal, hydrogen and hybrid vehicles. Also 2025's: the tables are unchanged since 2022 income.
const bands2024 = {
  VehicleType.car: [
    HorsepowerBand(1, 3, [Bracket(5000, 529), Bracket(20000, 316, 1065), Bracket(null, 370)]),
    HorsepowerBand(4, 4, [Bracket(5000, 606), Bracket(20000, 340, 1330), Bracket(null, 407)]),
    HorsepowerBand(5, 5, [Bracket(5000, 636), Bracket(20000, 357, 1395), Bracket(null, 427)]),
    HorsepowerBand(6, 6, [Bracket(5000, 665), Bracket(20000, 374, 1457), Bracket(null, 447)]),
    HorsepowerBand(7, null, [Bracket(5000, 697), Bracket(20000, 394, 1515), Bracket(null, 470)]),
  ],
  VehicleType.motorbike: [
    HorsepowerBand(1, 2, [Bracket(3000, 395), Bracket(6000, 99, 891), Bracket(null, 248)]),
    HorsepowerBand(3, 5, [Bracket(3000, 468), Bracket(6000, 82, 1158), Bracket(null, 275)]),
    HorsepowerBand(6, null, [Bracket(3000, 606), Bracket(6000, 79, 1583), Bracket(null, 343)]),
  ],
  VehicleType.moped: [
    HorsepowerBand(1, null, [Bracket(3000, 315), Bracket(6000, 79, 711), Bracket(null, 198)]),
  ],
};

/// 100% electric vehicles: the published tables, which are [bands2024] plus 20% as the tax office rounds them.
const electricBands2024 = {
  VehicleType.car: [
    HorsepowerBand(1, 3, [Bracket(5000, 635), Bracket(20000, 379, 1278), Bracket(null, 444)]),
    HorsepowerBand(4, 4, [Bracket(5000, 727), Bracket(20000, 408, 1596), Bracket(null, 488)]),
    HorsepowerBand(5, 5, [Bracket(5000, 763), Bracket(20000, 428, 1674), Bracket(null, 512)]),
    HorsepowerBand(6, 6, [Bracket(5000, 798), Bracket(20000, 449, 1748), Bracket(null, 536)]),
    HorsepowerBand(7, null, [Bracket(5000, 836), Bracket(20000, 473, 1818), Bracket(null, 564)]),
  ],
  VehicleType.motorbike: [
    HorsepowerBand(1, 2, [Bracket(3000, 474), Bracket(6000, 119, 1069), Bracket(null, 298)]),
    HorsepowerBand(3, 5, [Bracket(3000, 562), Bracket(6000, 98, 1390), Bracket(null, 330)]),
    HorsepowerBand(6, null, [Bracket(3000, 727), Bracket(6000, 95, 1900), Bracket(null, 412)]),
  ],
  VehicleType.moped: [
    HorsepowerBand(1, null, [Bracket(3000, 378), Bracket(6000, 95, 853), Bracket(null, 238)]),
  ],
};
