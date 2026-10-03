# Backend CI/CD on Windows IIS

**Deployment paused on 2026-10-03:** the operator reported a PM2 process named
`ttsmart-api` on the VPS. The deploy job is disabled until the process serving
port `5003` and the live application directory are verified. The CI job remains
active. Do not run the IIS deployment script against a PM2-managed process.

## Verified target and scope

- GitHub source branch: `main`.
- IIS site and application pool: `TTSmartMobileApi`.
- IIS physical path: `C:\Deploy\TTSmartMobileApi`.
- IIS binding: HTTP port `5003`, all IPs, no host name.
- Nginx: `https://mobile.dangnhap.net/` proxies to `http://127.0.0.1:5003` without changing the path. Nginx itself is outside this deployment.
- API target framework: .NET 10.

The IIS and Nginx values above came from screenshots and the Nginx configuration supplied on 2026-10-03. They have not been inspected on the VPS by this workflow.

## What the workflow does

`.github/workflows/backend-ci-cd.yml` runs on backend changes to `main` and on pull requests targeting `main`. A GitHub-hosted Windows runner restores, tests without the `SqlE2E` category, publishes the API, and uploads the exact publish directory as an artifact. It removes `appsettings.Development.json` from that artifact.

Production deployment is a separate, manual `workflow_dispatch` run from `main` with `deploy=true`. The deploy job uses a Windows self-hosted runner labelled `ttsmart-iis` and the GitHub `production` environment. It downloads the artifact from that same run and executes `backend/scripts/deploy-iis.ps1`.

The script verifies the IIS site, physical path, app pool, ASP.NET Core IIS module, .NET 10 runtime, artifact, and existing server configuration before changing files. It places `app_offline.htm`, backs up code to `C:\Deploy\TTSmartMobileApi-backups`, copies the tested publish output, removes `app_offline.htm`, then checks both:

- `http://127.0.0.1:5003/health/live` (IIS directly)
- `https://mobile.dangnhap.net/health/live` (through Nginx)

If either check fails, the script restores the previous code from its backup and fails the job. If rollback itself fails, `app_offline.htm` remains in place for manual recovery. The first previous release may not have `/health/live`; inspect the site manually after a rollback. Backups are retained for manual review and must be managed under the VPS retention policy.

The script preserves the server's `web.config` and `appsettings*.json`, plus `uploads`, `App_Data`, and `logs`. These contain deployment settings or runtime data. It only removes stale files listed in a manifest created by an earlier run of this script. On the first deployment, unrelated files already in the IIS folder are left alone. Database migrations, restores, seeds, and Nginx edits are not part of the workflow.

## One-time VPS and GitHub setup

1. Confirm the IIS site and app pool still match the values above. The screenshot shows `.NET CLR v4.0` on the app pool; set **.NET CLR Version = No Managed Code** for this ASP.NET Core app during an IIS maintenance window. Confirm the .NET 10 Hosting Bundle is installed; the deploy script refuses to run without its IIS module and runtime.
2. Confirm the existing `web.config` and `appsettings.json` in `C:\Deploy\TTSmartMobileApi` contain the settings the live site needs. The deployment preserves these files. Production values required by the application include `ConnectionStrings:AuthConnection`, `ConnectionStrings:NotificationConnection`, `ConnectionStrings:StationConnection`, and the `Jwt` issuer, audience, and signing key. Keep secrets on the VPS; do not put them in workflow YAML or the publish artifact.
3. Back up `C:\Deploy\TTSmartMobileApi\uploads` and `C:\Deploy\TTSmartMobileApi\App_Data` separately. Give the IIS app pool identity continued write access to them. They are intentionally excluded from code backups and file replacement.
4. Install a **repository-scoped** GitHub Actions self-hosted Windows runner on the VPS as a Windows service. Add the custom label `ttsmart-iis`. Run it with a dedicated account permitted to read IIS configuration and write only the API directory and backup directory. Do not route pull-request jobs to this runner; the workflow's PR job uses GitHub-hosted Windows.
5. In GitHub repository Settings → Environments, configure `production` with required reviewers and restrict deployment to `main`. The workflow is manual, but the environment rule adds an independent approval gate.
6. Confirm the VPS can reach GitHub Actions and can request `https://mobile.dangnhap.net/health/live` over TLS. The local health check uses the IIS port and does not require Nginx.

Before the first deployment, run the workflow once with `deploy=false` to confirm CI and artifact creation. Then run `deploy=true` in an approved window. The first production run and its rollback path still require live verification on the VPS.

For a manual preflight on the VPS, download or publish the artifact into a temporary directory and run `deploy-iis.ps1` with the same arguments as the workflow **without** `-Apply`. It validates the target without copying files.
