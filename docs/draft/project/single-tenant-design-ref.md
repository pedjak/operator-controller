++ b/docs/draft/project/single-tenant-simplification.md
# Design: Single-Tenant Simplification

**Status:** Draft
**Date:** 2026-03-05

## Summary

This design document proposes a set of changes to OLM v1 that re-affirm its single-tenant, cluster-admin-only operational model. Over time, several multi-tenancy concepts have crept into OLM v1's API surface and implementation despite the [explicit decision](../../project/olmv1_design_decisions.md) to not support multi-tenancy. This proposal removes those vestiges, simplifies the user experience, and strengthens the security posture of OLM v1.

The three themes of this proposal are:

1. **Re-affirm that multi-tenancy is not supported.** OLM v1 APIs are cluster-admin-only APIs.
2. **Remove multi-tenancy artifacts from the API and implementation.** Deprecate the service account field, remove SingleNamespace/OwnNamespace install mode support, and automate namespace management.
3. **Clarify security expectations in documentation.** Cluster-admins must not delegate ClusterExtension or ClusterCatalog creation to non-cluster-admin users.

## Motivation

### Service account complexity

The current `ClusterExtension.spec.serviceAccount` field requires cluster-admins to derive, create, and maintain a purpose-built ServiceAccount with precisely scoped RBAC for every extension they install. This process is documented in the [derive-service-account guide](../../howto/derive-service-account.md), which itself acknowledges the complexity:

> We understand that manually determining the minimum RBAC required for installation/upgrade of a `ClusterExtension` is quite complex and protracted.

This design exists because OLM v1 was originally designed to not run as cluster-admin itself. The intent was to prevent OLM from becoming a privilege escalation vector — a real problem in OLM v0 where any user who could create a Subscription effectively had cluster-admin access.

However, the ServiceAccount-per-extension model has proven to be a poor fit for a system that only cluster-admins should interact with:


### Watch namespace configuration

The `SingleOwnNamespaceInstallSupport` feature gate (currently GA, default enabled) allows operators to be installed in SingleNamespace or OwnNamespace mode. This feature exists solely for backwards compatibility with OLM v0 bundles, but contradicts the [core design decision](../../project/olmv1_design_decisions.md#watched-namespaces-cannot-be-configured-in-a-first-class-api) that OLM v1 will not configure watched namespaces:

> Kubernetes APIs are global. Kubernetes is designed with the assumption that a controller WILL reconcile an object no matter where it is in the cluster.

Supporting SingleNamespace and OwnNamespace modes creates:

### Namespace management

The current model requires the installation namespace to pre-exist and contain the specified ServiceAccount. This creates unnecessary manual steps and prevents OLM from leveraging CSV-provided namespace metadata (suggested-namespace annotations) that bundle authors have already defined.

## Benefits

Beyond simplifying the current user experience, these changes unlock future capabilities that were previously impossible or impractical due to multi-tenancy constraints.

### Simplified user experience


### Dependency discovery and reporting

With all operators guaranteed to watch all namespaces, dependency relationships between operators can be cleanly discovered, assessed, and reported. In the current model, an operator installed in SingleNamespace mode may or may not satisfy a dependency depending on which namespace it watches — a fact OLM cannot reliably determine. With AllNamespaces as the only mode, if an API's CRD exists on the cluster and a controller is installed for it, the dependency is satisfied. Period.

### Improved resolver diagnostics

In OLM v0, the dependency resolver had to be careful not to leak information in Subscription status messages about operators installed in other namespaces, because that could violate tenant isolation expectations. With multi-tenancy explicitly off the table, a future dependency resolver can provide rich, detailed diagnostic messages when resolution fails — including which installed operators were considered, why they didn't satisfy constraints, and what the user can do to fix the situation — without worrying about cross-namespace information leaks.

### Cluster-state-aware configuration templating

In OLM v0, the configuration engine could not plumb arbitrary resource contents into templates because reading resources from other namespaces could leak data across tenant boundaries. With a single-tenant model and cluster-admin permissions, a future configuration templating engine can safely query arbitrary cluster state — infrastructure node counts, available storage classes, cluster version, installed CRDs — and use that information to generate context-aware default configurations for extensions.

## Proposal

### 1. Deprecate and ignore `ClusterExtension.spec.serviceAccount`

**API change:**

**Behavior change:**

**Migration:**

**Documentation impact:**

### 2. Remove SingleNamespace and OwnNamespace install mode support

**Behavior change:**

**Rationale:**

**Documentation impact:**

### 3. Change `ClusterExtension.spec.namespace` to optional with automatic namespace management

**API change:**

**Behavior change — namespace determination:**

operator-controller determines the installation namespace using the following precedence (highest to lowest):

1. **`ClusterExtension.spec.namespace`** — If specified by the user, this is the namespace name used.
2. **`operatorframework.io/suggested-namespace` CSV annotation** — If the CSV provides a suggested namespace name, it is used.
3. **`<packageName>-system` fallback** — If neither of the above is present, operator-controller generates a namespace name from the package name.

**Behavior change — namespace body/template:**


**Behavior change — namespace lifecycle:**

  - It is created by operator-controller if it does not exist.
  - A pre-existing namespace results in a conflict error, consistent with the [single-owner objects](../../concepts/single-owner-objects.md) design. This ensures that managed resources are not accidentally adopted or clobbered.
  - It is deleted when the ClusterExtension is deleted (along with all other managed objects).

**Migration:**

### 4. Restrict API access: ClusterExtension and ClusterCatalog are cluster-admin-only

**No API or behavior changes.** This is a documentation and guidance change.

**Key points to document:**


**Documentation impact:**

## Impact on existing features and feature gates

| Feature / Feature Gate | Current State | Proposed State |
|---|---|---|
| `spec.serviceAccount` | Required field | Deprecated, ignored |
| `PreflightPermissions` | Alpha (default off) | Remove |
| `SyntheticPermissions` | Alpha (default off) | Remove |
| `SingleOwnNamespaceInstallSupport` | GA (default on) | Remove |
| `spec.namespace` | Required field | Optional field |
| `spec.config.inline.watchNamespace` | Accepted config | Validation error |
| operator-controller ClusterRoleBinding | Not cluster-admin | cluster-admin |

## Security analysis

### Current model


### Proposed model

  - It is binary: either you can create these resources or you cannot.
  - It aligns with how Kubernetes RBAC is designed to work.
  - It does not rely on cluster-admins correctly deriving complex RBAC for every extension.
  - It matches the reality of how OLM v1 is already deployed in most environments.

### Risk: compromise of operator-controller

With cluster-admin, a compromised operator-controller pod is a more severe risk. Mitigations:


## Rollout

This proposal involves breaking changes and should be rolled out in two phases:

1. **Phase 1 — Behavior change:** operator-controller is granted cluster-admin and begins using its own ServiceAccount for all API interactions. `spec.serviceAccount` is marked deprecated and ignored. `spec.namespace` becomes optional with automatic namespace management. SingleNamespace/OwnNamespace support is removed. The `PreflightPermissions`, `SyntheticPermissions`, and `SingleOwnNamespaceInstallSupport` feature gates and their associated code are removed. Documentation is updated to reflect all changes.

    No existing ClusterExtension installations will break — operator-controller's cluster-admin ServiceAccount is a strict superset of any permissions that a user-configured ServiceAccount would have had. The only impact is on security-conscious users who relied on the limited permissions of the configured ServiceAccount to constrain what OLM could do on behalf of a given ClusterExtension. For those users, the security boundary shifts from per-extension ServiceAccount RBAC to controlling who can create ClusterExtension resources.

2. **Phase 2 — API cleanup:** Remove `spec.serviceAccount` from the API in a future API version.

## Alternatives considered

### Keep ServiceAccount but automate its creation

An alternative would be to keep the ServiceAccount model but have operator-controller or a CLI tool automatically create and maintain the ServiceAccount with the correct RBAC.

**Rejected because:** This adds complexity to solve a problem that doesn't need to exist. If only cluster-admins create ClusterExtensions, the ServiceAccount is just an unnecessary indirection. Auto-generating it means operator-controller needs the permissions to create RBAC anyway, which is effectively cluster-admin.

### Allow AllNamespaces + SingleNamespace as a user choice

An alternative would be to continue allowing the user to choose between AllNamespaces and SingleNamespace modes.

**Rejected because:** This contradicts the core design principle that APIs are global in Kubernetes. It creates a false sense of isolation and introduces complexity for a use case (multi-tenancy) that OLM v1 explicitly does not support.

### Make ClusterExtension namespace-scoped to enable delegation

An alternative would be to create a namespace-scoped `Extension` API that could be safely delegated to non-cluster-admins.

**Rejected because:** The content installed by an extension (CRDs, cluster RBAC, webhooks) is inherently cluster-scoped. A namespace-scoped API would either need to be severely restricted in what it can install (making it useless for most operators) or would still be a privilege escalation vector.

## Work items

| # | Work item | Depends on |
|---|-----------|-----------|
| [01](single-tenant-simplification/01-cluster-admin.md) | Grant operator-controller cluster-admin | — |
| [02](single-tenant-simplification/02-deprecate-service-account.md) | Deprecate and ignore spec.serviceAccount | 01 |
| [03](single-tenant-simplification/03-remove-preflight-permissions.md) | Remove PreflightPermissions feature gate and code | — |
| [04](single-tenant-simplification/04-remove-synthetic-permissions.md) | Remove SyntheticPermissions feature gate and code | — |
| [05](single-tenant-simplification/05-remove-single-own-namespace.md) | Remove SingleNamespace/OwnNamespace install mode support | — |
| [06](single-tenant-simplification/06-optional-namespace.md) | Make spec.namespace optional with automatic namespace management | 02 |
| [07](single-tenant-simplification/07-simplify-contentmanager.md) | Simplify contentmanager to a single set of informers | 02 |
| [09](single-tenant-simplification/09-documentation.md) | Documentation updates | all |
