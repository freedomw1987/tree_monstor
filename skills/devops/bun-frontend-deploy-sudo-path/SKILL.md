---
name: bun-frontend-deploy-sudo-path
description: Bun frontend build + sudo deploy path resolution issue
triggers:
  - "bun run build succeeds but sudo cp fails with No such file or directory"
  - "frontend dist directory empty after deploy"
  - "bun build output not found by sudo cp"
---

# Bun Frontend Build & Deploy with Sudo

## Problem
After `bun run build` succeeds (shows output files in `dist/`), subsequent `sudo cp` or `sudo rsync` commands fail with "No such file or directory" even though `ls dist/` shows the files exist.

## Root Cause
`sudo` does NOT preserve `~` path expansion. When you run:
```bash
sudo cp -r ~/projects/pm-system/frontend/dist /target/
```
The `~` is expanded by the shell to `/home/ubuntu/...`, BUT sudo runs as root and `/home/ubuntu/...` might not exist from root's perspective, OR more likely the path gets mangled.

Additionally, each terminal session starts from a default working directory (`~/.openclaw/workspace/`), so relative paths like `~/projects/...` resolve differently than expected.

## Correct Deployment Pattern

### Build (run in correct directory):
```bash
cd ~/projects/pm-system/frontend && bun run build && ls -la dist/
```

### Deploy (use absolute paths, NOT ~):
```bash
sudo rm -rf /var/www/html && sudo cp -r /home/ubuntu/projects/pm-system/frontend/dist /var/www/html/
```

Or if the target is on the same filesystem:
```bash
sudo rm -rf /var/www/html
sudo cp -r /home/ubuntu/projects/pm-system/frontend/dist /var/www/html/
ls -la /var/www/html/  # verify BEFORE declaring success
```

## Key Insight
The `bun run build` output IS going to the right place. The issue is path resolution in **subsequent** sudo commands. Always use absolute paths (`/home/ubuntu/...`) instead of `~` when scripting with sudo.

## Verification Checklist
1. Build succeeds (`bun run build` exits 0, `dist/` has files)
2. Files exist at absolute path (`ls -la /home/ubuntu/projects/pm-system/frontend/dist/`)
3. Deploy command uses absolute paths (no `~`)
4. Post-deploy verification (`curl` the API endpoint)