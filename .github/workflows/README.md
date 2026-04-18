# GitHub Actions — currently disabled

Workflows in this directory are intentionally **disabled** in repo settings while the project is private.

Rationale: solo project, pre-launch, no team to coordinate with. The local `bin/check.sh` (run via lefthook pre-push) is the gate. Avoids spending CI minutes on a single-developer workflow.

When the repo goes public for the App Store launch, re-enable Actions in repo settings → Actions → General → Allow all actions. The `ci.yml` workflow is current and tested (last green run: April 2026).
