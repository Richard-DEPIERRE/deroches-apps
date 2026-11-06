// The HMRC and IRS rates, as checked in DAPP-137's `rate-tables` (CE-FACT-CHECK PASS, read 2026-11-05). Amounts are
// thousandths of a pound or a dollar per mile, like the French tables. A new year is one new line.
import 'french_bareme.dart' show BaremeSource;

/// HMRC approved mileage allowance payments for one tax year (6 April – 5 April), ITEPA 2003 s.230(2).
class HmrcYear {
  const HmrcYear({required this.carFirst10k, required this.carAbove10k, required this.motorcycle, required this.cycle});

  /// Cars and vans: the first 10,000 business miles of the tax year, all cars and vans together (s.230(3)).
  final int carFirst10k;
  final int carAbove10k;
  final int motorcycle;
  final int cycle;
}

/// Lists "from tax year 2011 to 2026" (45p/25p/24p/20p) and "from tax year 2026 to 2027" (55p from 6 April 2026,
/// Taxation (Energy and Vehicles) Act 2026 s.2). The 35p above 10,000 miles announced for 2027-28 is not law yet
/// (OOTLAR § 2.7): 2027-28 stays out until its statutory instrument is made (DAPP-137 rechecks from 2027-03-01).
const hmrcSource = BaremeSource(
  title: 'Travel — mileage and fuel rates and allowances (HMRC)',
  url:
      'https://www.gov.uk/government/publications/rates-and-allowances-travel-mileage-and-fuel-allowances/travel-mileage-and-fuel-rates-and-allowances',
  publishedOn: '2026-05-21',
);

/// By the year the tax year starts in: 2026 is 2026-27.
const hmrcRates = {
  2024: HmrcYear(carFirst10k: 450, carAbove10k: 250, motorcycle: 240, cycle: 200),
  2025: HmrcYear(carFirst10k: 450, carAbove10k: 250, motorcycle: 240, cycle: 200),
  2026: HmrcYear(carFirst10k: 550, carAbove10k: 250, motorcycle: 240, cycle: 200),
};

/// The IRS business standard mileage rate for miles driven from [from] (an ISO date, yyyy-mm-dd) until the next rate
/// or the end of the year: cars, vans, pickups and panel trucks, electric or not.
class IrsRate {
  const IrsRate(this.from, this.ratePerMileMilli);

  final String from;
  final int ratePerMileMilli;
}

/// Its table holds every period below: Notice 2024-08 (67¢), Notice 2025-5 (70¢), Notice 2026-10 (72.5¢) and
/// Announcement 2026-11 (76¢ from 1 July 2026). 2027 isn't published yet (DAPP-137 rechecks from 2026-12-15).
const irsSource = BaremeSource(
  title: 'Standard mileage rates (IRS)',
  url: 'https://www.irs.gov/tax-professionals/standard-mileage-rates',
  publishedOn: '2026-07-28',
);

/// By calendar year; a year may change rate mid-year, as 2026 did.
const irsRates = {
  2024: [IrsRate('2024-01-01', 670)],
  2025: [IrsRate('2025-01-01', 700)],
  2026: [IrsRate('2026-01-01', 725), IrsRate('2026-07-01', 760)],
};
