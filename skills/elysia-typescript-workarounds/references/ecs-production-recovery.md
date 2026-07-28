# ECS / CloudWatch Production Recovery (Bun bundle target incident)

Incident-response narrative extracted from the Bun production bundle target
pitfall. The framework-level rule stays in `SKILL.md`; the AWS runbook lives here.

**Production recovery pattern**:
1. Check ECS service: `aws ecs describe-services --cluster <cluster> --services <service>` — look for `running=0` and repeated task starts/drains.
2. Check stopped tasks: `aws ecs list-tasks --desired-status STOPPED` then `aws ecs describe-tasks` — exit code `1` points to app crash.
3. Read recent CloudWatch log streams for the task ID.
4. Fix Dockerfile build target to `--target=bun`, rebuild/push image, then `aws ecs update-service --force-new-deployment`.
5. Verify `running == desired`, `/health` returns OK, then test auth endpoint.
