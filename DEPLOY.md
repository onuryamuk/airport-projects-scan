# Publishing the dashboard

The page is static (HTML, CSS, JS and data files), so it can be hosted anywhere. What differs between options is whether the daily scan runs automatically and who can see the page.

| Option | Who can view | Refresh button | Effort | Cost |
|---|---|---|---|---|
| A. claude.ai artifact (already published) | People you share the link with (claude.ai login) | Shows last scan; scan runs locally, then republish | None | Free |
| B. GitHub Pages + scheduled workflow (recommended) | Anyone with the URL (public repo) or org members (private repo on GitHub Team/Enterprise) | Opens the workflow's Run button; daily scan runs on GitHub | 15 minutes | Free (public) |
| C. Company intranet / IIS / SharePoint | Staff on the corporate network | Needs the local server or a scheduled task on the host | Depends on IT | Internal |
| D. Cloud static hosting (Azure Static Web Apps, Netlify, Cloudflare Pages) | Anyone, or SSO-protected | Same as B if paired with a scheduler; otherwise scan locally | 30-60 minutes | Free tiers exist |

Before publishing anywhere public, decide whether the content should be public. The page carries a disclaimer that it is an independent research tool, not an official Surbana Jurong publication, and it contains only publicly reported information and one published procurement email address. A private repository or SSO-protected host is the safer default for internal BD intelligence.

## Option B: GitHub Pages with a daily scan (step by step)

Everything needed is already in this folder: `.github/workflows/daily-scan.yml`, `.nojekyll`, `.gitignore`, and scripts that run on PowerShell 7 (the GitHub runner) as well as Windows PowerShell 5.1.

1. Create an empty repository on GitHub (for example `airport-projects-scan`). For a private repository, GitHub Pages needs a Team or Enterprise plan; on a free account the repository must be public for Pages to work.
2. In this folder, push the prepared commit (replace the URL with yours):
   ```
   git remote add origin https://github.com/onuryamuk/airport-projects-scan.git
   git push -u origin main
   ```
   Git will prompt for your GitHub sign-in the first time.
3. In the repository, open **Settings > Pages**, set Source to "Deploy from a branch", choose `main` and `/ (root)`, and save. After a minute the site is live at `https://onuryamuk.github.io/airport-projects-scan/`.
4. Open **Settings > Actions > General** and confirm "Read and write permissions" under Workflow permissions, so the scan job can commit refreshed data.
5. Edit `data/config.js` and set `refresh_workflow_url` to `https://github.com/onuryamuk/airport-projects-scan/actions/workflows/daily-scan.yml` and `schedule_note` to `daily at 06:00 UTC`. Commit and push. The hosted Refresh button now links to the workflow's Run button.
6. Test it: open the Actions tab, select "Daily feed scan and publish", press **Run workflow**. When it finishes, reload the site; the header chip shows the new scan time and any new signals.

Daily runs happen at 06:00 UTC. Change the `cron` line in the workflow to adjust. Note that GitHub disables scheduled workflows on repositories with no activity for 60 days; any commit re-enables them.

### Reviewing signals on the hosted copy

The hosted page shows signals but cannot write to the repository, so "Mark reviewed" is hidden there. To confirm or dismiss items, edit the record in `data/projects_partN.json` (or remove the link from `data/signals.json` and add it to `dismissed`), then commit and push; the workflow rebuilds the bundle on its next run, or run `refresh/Build-Data.ps1` locally and push the generated files.

## Option C: intranet server

Copy the folder to the web server's document root. Serve it as static files. For a live Refresh button on the intranet, either run `refresh/Serve-Local.ps1` on the server (it exposes `/api/refresh` and `/api/dismiss` on port 8765 and can sit behind a reverse proxy) or register `refresh/Register-DailyTask.ps1` on the server so the data files refresh daily and the static site simply serves the latest files.

## Option D: cloud static hosting

Deploy the folder as a static site. Pair it with a scheduler that runs the scan and redeploys: on Azure this is a Timer-triggered Function or DevOps pipeline running the same PowerShell script; on Netlify or Cloudflare, use a GitHub repository as the source so the workflow from Option B does the scanning and the host redeploys on each commit.
