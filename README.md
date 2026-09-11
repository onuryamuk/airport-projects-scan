# Airport Projects Radar - operating instructions

Airport market intelligence tracker for business development in the aviation sector. Built 11 September 2026 from web research; every record cites at least one source that was opened during the build. Independent research tool; not an official Surbana Jurong publication and no brand assets are used.

## What is in the folder

| Path | Purpose |
|---|---|
| `index.html`, `assets/` | The dashboard. Open `index.html` in any modern browser (no server needed). |
| `data/projects_part1..3.json` | Editable project records (Europe; Middle East, North Africa, Central Asia; Asia Pacific and Australia). |
| `data/projects.json`, `data/projects.js` | Generated merged records loaded by the dashboard. Do not edit by hand; run `refresh\Build-Data.ps1`. |
| `data/sources.json` / `.js` | Source register with access test results and coverage gaps. |
| `data/refresh_status.json` / `.js` | When the last scan ran, feed status, candidates pending. |
| `data/candidates.json` | Items found by the feed scan that may be material developments (analyst review queue). |
| `data/world.js` | Natural Earth 1:110m coastlines as an SVG path for the map. |
| `refresh/Refresh-Feeds.ps1` | Feed scan: fetches RSS/pages, matches against tracked airports, writes candidates and refresh status. |
| `refresh/feeds.json` | Feeds and pages the scan checks. Add or remove sources here. |
| `refresh/Build-Data.ps1` | Validates and rebuilds the data bundle after edits. |
| `refresh/Register-DailyTask.ps1` | Optional: registers a daily Windows Task Scheduler job for the scan. |
| `refresh/Serve-Local.ps1` | Local web server for the dashboard; exposes the Refresh scan and Mark reviewed endpoints. |
| `data/signals.json` / `.js` | Unreviewed source signals attached to records by the scan, plus dismissed links. |
| `METHOD.md` | Prioritisation method, definitions and region mapping. |
| `research/` | Notes and raw page text captured during the build (evidence trail). |

## Daily use

1. Open `index.html`. The header chip shows when sources were last scanned. Project cards show their own "latest substantive update" date, which is different.
2. Use the filters (region, country, airport, type, stage, procurement, priority, updated since). Totals in the KPI strip follow the current filter and always reconcile with the table.
3. Click a row, map marker, calendar item or feed item to open the detail panel. Sourced facts and analyst judgments are labelled separately.
4. Export CSV gives the filtered rows with all fields. If the browser blocks downloads (for example inside a sandboxed viewer), the CSV text appears below the table for copying.

## Refresh button on the page

Start the local server, then open the dashboard from it and press **Refresh scan** in the header:
```
powershell -ExecutionPolicy Bypass -File refresh\Serve-Local.ps1
```
then browse to `http://localhost:8765/`. The button runs the feed scan on this machine, reloads the data in place and reports feeds reached, new signals on tracked projects, possible new projects and unreachable sources.

What "updating the relevant opportunities" means here: new coverage that mentions a tracked airport is attached to that record as an **unreviewed source signal** (badge in the table, section at the top of the detail panel, list in the New and changed tab). Verified fields (stage, value, dates, parties, score) do not change until an analyst confirms the item is a material development and edits the record; a republished article is never counted as a change. "Mark reviewed" removes a signal and stops later scans re-attaching the same link. Unmatched items about airport development appear under "Possible new projects".

The hosted copy of the dashboard (the claude.ai artifact link) cannot run a scan because its sandbox blocks outbound requests; its button explains this and shows the last scan time. Republish the artifact after a local scan to update the hosted copy.

## Refresh process (script)

The refresh is a scheduled scan plus analyst review. It does not create or change verified fields on its own, because a republished article is not a new development and automatic matching cannot judge materiality.

1. Run the scan (from the folder root), or press Refresh scan on the locally served page:
   ```
   powershell -ExecutionPolicy Bypass -File refresh\Refresh-Feeds.ps1
   ```
   It writes `data\candidates.json`, updates `data\refresh_status.json/.js`, appends to `data\scan_log.tsv`, and flags records whose latest update is older than 180 days.
2. Review `data\candidates.json`. For each item that is a material change (new stage, award, value, party, date), edit the relevant record in `data\projects_partN.json`: add a `history` entry, add the source to `sources`, update `dates.latest_update`, `stage`, `procurement_status`, `milestones` and `last_verified`. For a genuinely new project, add a record with a unique `id`, coordinates and at least one source.
3. Rebuild the bundle:
   ```
   powershell -ExecutionPolicy Bypass -File refresh\Build-Data.ps1
   ```
   The build refuses duplicate ids, records without sources and scores above 20.
4. Reload `index.html`. If the dashboard is also published as a web artifact, republish it with the updated `data/` files.

### Scheduling

Daily scanning needs a machine that is on and connected. `refresh\Register-DailyTask.ps1 -Time 07:30` registers a Windows Task Scheduler job; run it deliberately, because it creates persistent configuration on the workstation. This is a scheduled scan, not continuous monitoring, and the review step in section 2 remains manual. Hosting the scan on a server or a cloud scheduler would need credentials and infrastructure that were not available in this build; the script is self-contained PowerShell 5.1 and can be moved as-is.

### Known access limits

Some official sites block automated requests (HTTP 403): cpk.pl, schiphol.nl, perthairport.com.au, ppp.gov.ph and others listed in the Sources tab. Records that depend on them carry a flag and should be verified by opening the page in a browser. Procurement portals (TED, PhilGEPS, Etimad, goszakup, SICAP, Thai e-GP) are not scanned automatically.

## Data quality rules

- Never invent budgets, dates, contacts or appointments; use "Not publicly disclosed".
- Keep total project values separate from individual contract values (`value` vs `contracts`).
- When sources conflict, keep both figures and add a flag rather than picking one silently.
- One record per project; separate phases or packages go in `contracts`, `milestones` or a separate record only when they are procured separately.
- Each `history` entry is a material development with a source index; do not add entries for coverage of the same fact.
