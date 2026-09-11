// Site configuration for hosted copies of the dashboard (GitHub Pages, intranet, etc.).
// refresh_workflow_url: link to the GitHub Actions "Run workflow" page (or any page that triggers the scan).
//   Leave empty when there is no hosted scan. Example: https://github.com/<org>/<repo>/actions/workflows/daily-scan.yml
// schedule_note: shown in the Refresh dialog on hosted copies.
window.AMI_CONFIG = {
  refresh_workflow_url: "https://github.com/onuryamuk/airport-projects-scan/actions/workflows/daily-scan.yml",
  schedule_note: "daily at 06:00 UTC on GitHub Actions"
};
