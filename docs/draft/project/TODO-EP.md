# TODO: Enhancement Proposal — Deprecate spec.serviceAccount

Based on [EP #1860](https://github.com/openshift/enhancements/pull/1860) (closed),
[PR #2544 design doc](https://github.com/operator-framework/operator-controller/pull/2544),
and [implementation PR #2770](https://github.com/operator-framework/operator-controller/pull/2770).

## Source materials

- [X] Copy EP #1860 content as starting point → `docs/draft/project/service-account-deprecation-ep.md`
- [X] Save #1860 reviewer comments as reference → `docs/draft/project/ep-reviewer-feedback.md`
- [X] Save #2544 design doc as reference → `docs/draft/project/single-tenant-design-ref.md`

## Reviewer concerns to address (from EP #1860)

### everettraven (API reviewer)

- [ ] "Rarely helpful" not justified — use #2544's detailed explanation of SA model failures (false sense of security, SA reference escalation, usability burden)
- [ ] Privilege escalation risk with cluster-admin — explain risk already exists (any CE writer can reference any SA in any namespace); cluster-admin makes it explicit
- [ ] Deprecated fields should still function — clarify: field is accepted but ignored (no validation error), existing CEs continue working
- [ ] Downgrade handling — OCP doesn't support minor version downgrades; field remains in API so no serialization issue
- [ ] Older client compatibility — field stays in API with `omitzero`; clients reading it see empty value, not missing field
- [ ] `x-kubernetes-deprecated` doesn't exist — we use ValidatingAdmissionPolicy with `validationActions: [Warn]` instead (kubernetes/kubernetes#131817)
- [ ] Alternative: better client tooling — address as considered alternative, doesn't solve fundamental SA model issues
- [ ] Automatic upgrade privilege escalation — OLM could stamp out malicious code; address in risks section
- [ ] How do users manage controller permissions — document RBAC + VAP as the scoping mechanism
- [ ] What are "Synthetic Permissions" — explain and justify removal

### JoelSpeed (API reviewer)

- [ ] Should support three paths (no SA, namespace-scoped admin, full least-privilege) — biggest tension; propose RBAC + VAP as replacement for per-SA scoping (Stream 6 / OPRUN-4634)
- [ ] Still need EP process for this change — yes, this EP is that process

### grokspawn

- [ ] Deprecation tracking — propose `FieldDeprecated` status condition in EP (see analysis below)
- [ ] Include preflight permissions removal — yes, those are alpha/not GA'd, removed in implementation
- [ ] GA'd OCP APIs have never been removed — discuss field removal timeline, keeping field in API indefinitely as ignored

## Deprecation tracking — status condition analysis

grokspawn suggested deprecation tracking similar to how k8s tracks deprecated API usage
(metrics, warnings). Joe asked whether the log warning should be a metric or removed.

### Current implementation

- **VAP admission warning** — kubectl warning on create/update when `spec.serviceAccount` is set
- **Controller log** — `l.Info("spec.serviceAccount is deprecated...")` on every reconciliation
- **Godoc** — `Deprecated:` marker on the field

### Proposed: `FieldDeprecated` status condition

A status condition on ClusterExtension that persists (unlike Progressing which resets on
successful reconciliation), visible via `kubectl describe`, queryable programmatically.

### OpenShift precedent analysis

**No OpenShift operator currently reports field-level deprecation via a status condition.**
The ~50+ deprecated fields in `openshift/api` are handled in three patterns:

| Pattern | Example | How |
|---|---|---|
| **Active enforcement** | `webhookTokenAuthenticators` (cluster-kube-apiserver-operator) | Sets `AuthenticationConfigUpgradeable=False` to block cluster upgrades. [PR #1009](https://github.com/openshift/cluster-kube-apiserver-operator/pull/1009) |
| **Silently ignored** | `accessTokenInactivityTimeoutSeconds` (cluster-authentication-operator) | Field in struct for compat, not processed. No warning, no condition, no event. **Most common pattern.** |
| **Completely bypassed** | `consolePublicURL` (console-operator) | Operator doesn't read the field at all. Uses independent mechanism. [PR #218](https://github.com/openshift/console-operator/pull/218) |

The closest precedent is `UnservableInFutureVersions` condition on Routes
([openshift/api PR #1722](https://github.com/openshift/api/pull/1722)), which warns about
configurations incompatible with future versions. It feeds into the operator-level
`Upgradeable` ClusterOperator condition.

Field-level deprecation in CRD schemas (`x-kubernetes-deprecated`) is
[not yet available](https://github.com/kubernetes/kubernetes/issues/131817).

### cluster-olm-operator: the proper downstream mechanism

[cluster-olm-operator](https://github.com/openshift/cluster-olm-operator/) manages OLMv1
in OpenShift and already has the infrastructure for deprecation tracking:

- Uses `library-go` `v1helpers.OperatorClient` to manage operator status
- `staticUpgradeableConditionController` sets baseline `Upgradeable=True`
- `incompatibleOperatorController` lists ClusterExtensions, checks `olm.maxOpenShiftVersion`,
  sets `InstalledOLMOperatorsUpgradeable=False` to block upgrades when incompatible bundles
  are installed

### Standard ClusterOperator condition types

| Condition | Purpose | Blocks upgrades? |
|---|---|---|
| `Available` | Component is functioning | No |
| `Progressing` | Rolling out changes | No |
| `Degraded` | Not matching desired state | No |
| `Upgradeable` | Safe to upgrade | **Yes** (when False) |
| `EvaluationConditionsDetected` | Detected condition needing attention before future upgrade | **No** (advisory) |

`EvaluationConditionsDetected` is the best fit — defined as "detection logic that evaluates
the introduction of an invasive change that could potentially result in highly visible alerts,
breakages or upgrade failures." It warns without blocking.

### Proposed two-phase approach in cluster-olm-operator

**Phase 1 (deprecation release):** New controller sets
`EvaluationConditionsDetected=True` with reason `DeprecatedServiceAccountInUse` and message
listing affected CEs. Advisory — doesn't block upgrades.

**Phase 2 (removal release):** Switch to `Upgradeable=False` with reason
`DeprecatedServiceAccountMustBeCleared`. Blocks upgrade to the release that removes the field,
forcing admins to clear the field first. Same pattern as `incompatibleOperatorController`.

### Recommendation

- **Upstream (operator-controller):** VAP warning + godoc is sufficient. Already exceeds
  what any OpenShift operator does for field-level deprecation.
- **Downstream (cluster-olm-operator):** Add controller using `EvaluationConditionsDetected`
  (phase 1) then `Upgradeable=False` (phase 2). Follows existing `incompatibleOperatorController`
  pattern.
- **EP:** Propose both layers — admission-time warning (VAP, upstream) and ClusterOperator
  condition (downstream). No need for a novel `FieldDeprecated` condition type on the CE itself.

## EP revision tasks

- [ ] Clean up EP frontmatter (update authors, dates, tracking-link to OCPSTRAT-3040)
- [ ] Rewrite Motivation section using #2544's stronger rationale
- [ ] Update Goals to match OCPSTRAT-3040 requirements (15 items)
- [ ] Update Proposal/API Changes to reflect actual implementation:
  - `omitzero` instead of pointer
  - Godoc following OpenShift convention (`Deprecated:` at end)
  - Relaxed immutability rule (allow clearing)
  - ValidatingAdmissionPolicy for kubectl warnings
  - CRB renamed to `operator-controller-cluster-admin-rolebinding`
  - Install script handles upgrade (old CRB + ClusterRole cleanup)
- [ ] Update Proposal/Controller Logic to reflect actual implementation:
  - Controller uses own SA for all interactions
  - `ServiceAccountDeprecationWarning` logs when field is set
  - All SA impersonation/token/synthetic code removed
  - ContentManager replaced with shared TrackingCache
- [ ] Add Design Details section:
  - TrackingCache architecture (single global cache, event suppression)
  - `WithWatchesRawSource` builder option gated on Helm runtime
  - Nil guard for TrackingCache in Apply path
- [ ] Update Test Plan to reflect actual testing:
  - Unit tests for admission, helm applier
  - envtest for VAP warning capture
  - e2e: standard (49 scenarios), experimental (54 scenarios), upgrade (st2st)
  - Deprecation warning scenario
- [ ] Update Graduation Criteria / Deprecation Plan for OCP timeline
- [ ] Update Upgrade / Downgrade Strategy:
  - CRB rename handles roleRef immutability
  - Old RBAC resources cleaned up by install script
  - Field remains in API, no downgrade issue
- [ ] Add Alternatives Considered:
  - Keep SA functional during deprecation (everettraven's preference)
  - Synthetic permissions / impersonation model (#1897)
  - Better client tooling for SA derivation
  - Three paths: no SA / namespace admin / full least-privilege (JoelSpeed)
  - RBAC + VAP as replacement for per-SA scoping

## Final steps

- [ ] Review draft EP for completeness and consistency
- [ ] Port to openshift/enhancements repo (fork, branch from master)
- [ ] Open PR against openshift/enhancements
- [ ] Link EP PR to OPRUN-4629 and OCPSTRAT-3040
