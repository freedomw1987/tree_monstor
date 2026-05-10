---
name: docker-port-forward-shadow-debug
description: Diagnose when Docker containers shadow host services on well-known ports (80/443), causing reverse-proxy traffic to be intercepted by the wrong process.
---

# Docker Port Forward Shadow Debug

## Trigger Conditions
When debugging reverse-proxy/HTTPS issues where:
- `ss -tlnp` shows nginx owns port 443
- But HTTP responses contain `server: Caddy` (or another unexpected server)
- Or API requests to the expected reverse-proxy return NOT_FOUND/404 unexpectedly
- Or a service is definitely running but requests go somewhere else

## Key Insight
Docker containers can expose ports to the host with `-p 443:443`, which **shadows** services running directly on the host (like nginx). The container's process becomes the actual listener on the host's port 0.0.0.0:443.

## Diagnostic Checklist (in order)

1. **Check HTTP response header**:
   ```bash
   curl -sv https://domain.com/ 2>&1 | grep "< server:"
   ```
   - If it says "Caddy" but you expect nginx → Caddy is intercepting
   - Unexpected server name → find what's actually serving

2. **Check Docker containers with port 443**:
   ```bash
   sudo docker ps --format "{{.ID}} {{.Image}} {{.Names}} {{.Ports}}"
   ```
   - Look for any container listing `443/tcp` in its ports
   - A container with `-p 443:443` will shadow host services on 443

3. **Kill the shadow process** (temp fix):
   ```bash
   sudo kill -9 <PID>
   ```
   - If it respawns → it's managed by systemd or Docker restart policy
   - Check: `systemctl status <PID>` or `systemctl status docker-<container-id>.scope`

4. **Find the Docker container config**:
   ```bash
   sudo docker inspect <container-id> --format '{{.HostConfig.PortBindings}}'
   ```

5. **Permanent fix**: Remove the port mapping from docker-compose.yml or stop/rm the container

## Why `ss` Misleads
`ss -tlnp` shows which process has the socket open. When Docker uses `docker-proxy` or the container's process inherits the socket via port forwarding, nginx may show in `ss` output because it re-execs or shares the socket, but the actual traffic goes to the container. Always verify by checking actual HTTP response headers.

## Prevention
- Avoid mapping port 443/80 directly in Docker for reverse-proxy containers
- Use Docker networks instead of host networking for side-by-side deployments
- When deploying alongside existing host services, proxy through the host's nginx
