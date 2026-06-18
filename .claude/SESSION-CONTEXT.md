# Session Context: Enhancement Proposal for spec.serviceAccount deprecation

Read this file at the start of a new session to get full context for continuing the EP work.

## What we're doing

Writing an OpenShift enhancement proposal (EP) for deprecating `spec.serviceAccount` on
ClusterExtension and adopting cluster-admin scope. This EP is required by Joe Lanford's
`/hold` on [PR #2770](https://github.com/operator-framework/operator-controller/pull/2770)
before the implementation can merge.

## Files in this worktree (`sa-deprecation-ep` branch)

- `docs/draft/project/service-account-deprecation-ep.md` — EP #1860 content as starting point (needs major revision)
- `docs/draft/project/TODO-EP.md` — full checklist: reviewer concerns, revision tasks, deprecation tracking analysis
- `docs/draft/project/ep-reviewer-feedback.md` — all reviewer comments from EP #1860 organized by EP section
- `docs/draft/project/single-tenant-design-ref.md` — PR #2544 design doc for reference (stronger motivation text)

## Key decisions already made

- **omitzero instead of pointer** — OpenShift API conventions advise against pointers for CRDs
- **Godoc format** — field name first, `Deprecated:` at end (satisfies both OpenShift and Go conventions)
- **VAP for kubectl warnings** — since `x-kubernetes-deprecated` for field-level deprecation doesn't exist yet (kubernetes/kubernetes#131817)
- **CRB renamed** to `operator-controller-cluster-admin-rolebinding` to avoid immutable roleRef issue on upgrade
- **No `FieldDeprecated` status condition** on CE — no OpenShift precedent; propose in EP for discussion instead

## Downstream deprecation tracking strategy

`cluster-olm-operator` (github.com/openshift/cluster-olm-operator) manages OLMv1 in OpenShift.
It already has `incompatibleOperatorController` that lists CEs and sets `Upgradeable` conditions.

Proposed two-phase approach:
- **Phase 1 (deprecation release):** `EvaluationConditionsDetected=True` — advisory, doesn't block upgrades
- **Phase 2 (removal release):** `Upgradeable=False` — blocks upgrade until deprecated field is cleared

## OpenShift deprecated field patterns (from openshift/api analysis)

~50+ deprecated fields across the repo. Three patterns, none use status conditions:
1. **Active enforcement** — `webhookTokenAuthenticators`: `Upgradeable=False` blocks upgrades
2. **Silently ignored** — `accessTokenInactivityTimeoutSeconds`: no feedback at all (most common)
3. **Completely bypassed** — `consolePublicURL`: operator doesn't read the field

Our VAP + godoc approach already exceeds all of these.

## Critical reviewer concerns from EP #1860

- **JoelSpeed:** wanted three paths (no SA, namespace admin, full least-privilege) not pure deprecation. Propose RBAC + VAP as replacement.
- **JoelSpeed:** "I don't think we can do this until we have something new to point users to that replaces this."
- **everettraven:** deprecated fields should still function until removed; privilege escalation risk; "rarely helpful" not justified
- **grokspawn:** deprecation metrics/tracking; GA'd OCP APIs never removed

## EP template compliance

Current draft is missing required sections from the official EP template (`guidelines/enhancement_template.md`):
User Stories, Workflow Description, API Extensions, Topology Considerations, Implementation Details,
Open Questions, Dev Preview→TP→GA graduation subsections, Version Skew Strategy, Operational Aspects,
Support Procedures, Infrastructure Needed.

## Related tickets

- OCPSTRAT-3040 — parent feature
- OPRUN-4629 — enhancement proposal ticket (child of OPRUN-4630)
- OPRUN-4675 — enhancement proposal task (child of OPRUN-4630)

## Related PRs/EPs

- [PR #2770](https://github.com/operator-framework/operator-controller/pull/2770) — implementation (on hold)
- [EP #1860](https://github.com/openshift/enhancements/pull/1860) — prior EP attempt (closed)
- [EP #1897](https://github.com/openshift/enhancements/pull/1897) — alternative approach: make SA optional with synthetic permissions (closed)
- [PR #2544](https://github.com/operator-framework/operator-controller/pull/2544) — prior implementation attempt with design doc
