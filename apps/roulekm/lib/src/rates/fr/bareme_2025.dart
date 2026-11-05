// Barème kilométrique for 2025 income (déclaration 2026). Figures and source: DAPP-137's `rate-tables`.
// The figures are 2024's, unchanged by the official text.
import '../french_bareme.dart';
import 'bareme_2024.dart';

const bareme2025 = FrenchBareme(
  year: 2025,
  source: BaremeSource(
    title: 'BOI-BAREME-000001',
    url: 'https://bofip.impots.gouv.fr/bofip/2185-PGP.html',
    publishedOn: '2026-01-01',
  ),
  bands: bands2024,
);
