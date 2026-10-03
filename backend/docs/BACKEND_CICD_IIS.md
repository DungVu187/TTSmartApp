# Backend CI/CD on Windows IIS

**Deployment paused on 2026-10-03:** the operator reported that PM2 runs a
different `ttsmart-api` on port `5000`; the mobile API is routed by Nginx to
the IIS site on port `5003`. The deploy job remains disabled until the runner's
filesystem permissions and the live port `5003` route are verified. CI remains
active. Do not run this IIS script against the PM2-managed service.

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

While CD is paused, a manual run with `runner_preflight=true` and `deploy=false` checks that the runner can see the .NET 10 runtime, IIS module file, existing site configuration, and write tiny temporary probe files to the site and backup directories. It removes both probes immediately and does not replace application files. Create `C:\Deploy\TTSmartMobileApi-backups` and grant the runner service account the needed permissions before expecting this check to pass.

The VPS currently blocks PowerShell script files under its machine execution policy. The runner preflight and deploy steps invoke PowerShell with `-ExecutionPolicy Bypass` for that single job process; they do not change the machine-wide policy. If a domain Group Policy enforces script restrictions, this process-level setting may still be overridden and must be handled by the server administrator.

The script verifies the fixed site name and path, ASP.NET Core IIS module file, .NET 10 runtime, artifact commit ID, and existing server configuration before changing files. The operator must separately confirm the IIS site and app pool in IIS Manager because the runner uses the low-privilege `NETWORK SERVICE` account. The script places `app_offline.htm`, backs up code to `C:\Deploy\TTSmartMobileApi-backups`, copies the tested publish output, removes `app_offline.htm`, then checks that both endpoints report the exact deployed commit:

- `http://127.0.0.1:5003/health/live` (IIS directly)
- `https://mobile.dangnhap.net/health/live` (through Nginx)

If either check fails, the script restores the previous code from its backup and fails the job. If rollback itself fails, `app_offline.htm` remains in place for manual recovery. The first previous release may not have `/health/live`; inspect the site manually after a rollback. Backups are retained for manual review and must be managed under the VPS retention policy.

The script preserves the server's `web.config` and `appsettings*.json`, plus `uploads`, `App_Data`, and `logs`. These contain deployment settings or runtime data. It only removes stale files listed in a manifest created by an earlier run of this script. On the first deployment, unrelated files already in the IIS folder are left alone. Database migrations, restores, seeds, and Nginx edits are not part of the workflow.

## One-time VPS and GitHub setup

1. Confirm the IIS site and app pool still match the values above. The screenshot shows `.NET CLR v4.0` on the app pool; set **.NET CLR Version = No Managed Code** for this ASP.NET Core app during an IIS maintenance window. Confirm the .NET 10 Hosting Bundle is installed; the deploy script refuses to run without its IIS module and runtime.
2. Confirm the existing `web.config` and `appsettings.json` in `C:\Deploy\TTSmartMobileApi` contain the settings the live site needs. The deployment preserves these files. Production values required by the application include `ConnectionStrings:AuthConnection`, `ConnectionStrings:NotificationConnection`, `ConnectionStrings:StationConnection`, and the `Jwt` issuer, audience, and signing key. Keep secrets on the VPS; do not put them in workflow YAML or the publish artifact.
3. Back up `C:\Deploy\TTSmartMobileApi\uploads` and `C:\Deploy\TTSmartMobileApi\App_Data` separately. Give the IIS app pool identity continued write access to them. They are intentionally excluded from code backups and file replacement.
4. Install a **repository-scoped** GitHub Actions self-hosted Windows runner on the VPS as a Windows service. Add the custom label `ttsmart-iis`. The installed runner uses `NT AUTHORITY\NETWORK SERVICE`; grant that account the filesystem permissions needed to write the API directory and `C:\Deploy\TTSmartMobileApi-backups`. Confirm its access without granting IIS administration privileges. Do not route pull-request jobs to this runner; the workflow's PR job uses GitHub-hosted Windows.
5. In GitHub repository Settings → Environments, configure `production` with required reviewers and restrict deployment to `main`. The workflow is manual, but the environment rule adds an independent approval gate.
6. Confirm the VPS can reach GitHub Actions and can request `https://mobile.dangnhap.net/health/live` over TLS. The local health check uses the IIS port and does not require Nginx.

Before the first deployment, run the workflow with `runner_preflight=true` and `deploy=false` to confirm CI, the artifact, and the runner's local permissions. After that passes and the deploy job is enabled, run `deploy=true` in an approved window. The first production run and its rollback path still require live verification on the VPS.

For a manual preflight on the VPS, download or publish the artifact into a temporary directory and run `deploy-iis.ps1` with the same arguments as the workflow **without** `-Apply`. It validates the target without copying files.
