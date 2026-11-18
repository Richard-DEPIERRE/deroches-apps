# ADR 0008: Roulekm's yearly PDF log is drawn on the phone with the `pdf` package

- Status: proposed
- Date: 2026-11-18
- Deciders: Flutter Engineer 2 (review: Mobile Tech Lead, then Richard)
- Issue: DAPP-330

## Context

Roulekm's Pro export is one PDF per vehicle per year (DAPP-141 §9): A4 in France and the UK, US Letter in the US,
the trips by month with the column headings on every page, "Page x of y", the year's total box and a footer. It must
be made on the phone: no server, nothing the user logged leaves the device except the file they share themselves
(rules section 2, anti-goal 1). ADR 0001 section 13 asks an app to give the reason for any library the kit doesn't
name. Facts checked on pub.dev on 2026-11-18:

- `pdf` (github.com/DavBfr/dart_pdf, Apache 2.0): pure Dart, no platform code, no network access. It lays out pages
  with widgets close to Flutter's and embeds TrueType fonts. 160/160 pub points; latest 3.13.1 (2026-09-19).
- 3.13.x needs `xml` 7; the workspace resolves `xml` 6.6.1 (Roulekm's backup-rules test), and pub.dev can't be
  reached from the agent sandbox to bring in another version. 3.12.0 was already in the shared pub cache.

## Decision

1. **`pdf` ^3.12.0** in `apps/roulekm` only. It draws the log with Barlow, the app's own font (OFL), so the file looks
   like the app and like nothing official (anti-goal 4).
2. **The content is a plain model** (`PdfLog`, made by `yearPdfLogs` from the logbook and the strings): every
   text in the user's language, the rows, the totals. `renderPdf` only lays it out. The tests read the model in
   French and English (a PDF made with embedded fonts holds glyph ids, not text, so reading text back would need a
   PDF parser). They also check the rendered file's paper size, page count and font.
3. **Column headings in the page header.** The package's `Table` doesn't repeat header rows across pages, so the
   heading row is drawn in `MultiPage`'s header with the same fixed column widths as the trips.

Rejected:
- **`printing`** (same author): adds native code on iOS and Android for a print dialog and a preview we don't need.
  The share sheet (`share_plus`, DAPP-329) already hands the file on.
- **`syncfusion_flutter_pdf`**: a commercial licence for companies over a revenue threshold, and a heavier library.
- **HTML to PDF through a WebView**: platform code, different output on iOS and Android, and slower.

## Consequences

- No new data is collected and nothing is sent anywhere: no `PRIVACY` change. The app gets larger by the package
  (pure Dart) and the three Barlow weights it already ships.
- The PDF is drawn on the main isolate when the user taps the button. A year of a few hundred trips is a few pages;
  if a large log shows jank, move `renderPdf` to `Isolate.run`, passing the font bytes and the model.
- Moving to `pdf` 3.13 waits until the workspace moves to `xml` 7.
