// Barème kilométrique for 2025 income (declared in 2026), as checked in DAPP-137's `rate-tables` (CE-FACT-CHECK PASS,
// read 2026-11-05): Brochure pratique 2026, Déclaration des revenus 2025, p. 53 and p. 108 (DGFiP, PDF of 2026-03-17),
// and CGI annexe IV art. 6 B (see bareme_2024.dart). Not revalued: the tables are 2024's (service-public A14686,
// 2026-04-09: "comme en 2025, les barèmes kilométriques ne sont pas revalorisés").
import '../french_bareme.dart';
import 'bareme_2024.dart';

const bareme2025 = FrenchBareme(
  year: 2025,
  source: BaremeSource(
    title: 'Brochure pratique 2026, Déclaration des revenus 2025 (DGFiP)',
    url: 'https://www.impots.gouv.fr/www2/fichiers/documentation/brochure/ir_2026/pdf_integral/Brochure-IR-2026.pdf',
    publishedOn: '2026-03-17',
    readOn: '2026-11-05',
  ),
  bands: bands2024,
  electricBands: electricBands2024,
);
