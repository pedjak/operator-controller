---
title: serviceaccount-field-deprecation
authors:
  - "@rashmigottipati"
reviewers:
  - "@grokspawn"
  - "@trgeiger"
  - "@joelanford"
approvers:
  - "@joelanford"
api-approvers:
  - "@everettraven"

creation-date: 2025-10-08
last-updated: 2025-10-20
status: implementable

# Service Account Field Deprecation

## Release Signoff Checklist


## Summary

Deprecate the `.spec.serviceAccount` field from the ClusterExtension API in the operator-controller. This field was originally introduced to enforce least privilege by requiring users to provide a ServiceAccount with the necessary RBAC permissions to manage extension content. This proposal removes that requirement and simplifies controller logic and behavior.

## Motivation

The original intent of `.spec.serviceAccount` was to support a least-privilege model by allowing users to provide custom `ServiceAccount` with fine-grained permissions. In practice, this design introduced considerable operational and technical complexity, including:


Given the limited benefit and high complexity of this approach, we propose simplifying the model:



### Goals


### Non-Goals


## Proposal

### API Changes

Update the `ClusterExtension` API to mark `.spec.serviceAccount` as:

  - x-kubernetes-deprecated: true
  - Include appropriate description to warn users the field is ignored

Also, update CRD validation schema accordingly. 

**Example:**

```go
// Before (current)
type ClusterExtensionSpec struct {
    ...
    ServiceAccount ClusterExtensionServiceAccount `json:"serviceAccount"`
    ...
}
```

```go
// After (deprecated and optional)
type ClusterExtensionSpec struct {
    ...
    // Deprecated: This field is ignored and will be removed in a future release.
    // +optional
    // +kubebuilder:validation:XValidation:message="serviceAccount is deprecated and ignored"
    ServiceAccount *ClusterExtensionServiceAccount `json:"serviceAccount,omitempty"`
    ...
}
```

**YAML Example:**

```yaml
# Before (serviceAccount was required)
apiVersion: olm.operatorframework.io/v1alpha1
kind: ClusterExtension
metadata:
  name: argocd-extension
spec:
  installNamespace: argocd
  packageName: argocd-operator
  version: 0.6.0
  serviceAccount:
    name: argocd-installer
```

```yaml
# After (field is deprecated, optional, and therefore ignored and removed)
apiVersion: olm.operatorframework.io/v1alpha1
kind: ClusterExtension
metadata:
  name: argocd-extension
spec:
  installNamespace: argocd
  packageName: argocd-operator
  version: 0.6.0
  # serviceAccount is now deprecated and has no effect
```

### Controller Logic Changes

  - Token Acquisition: Eliminate use of TokenRequest API to fetch short-lived tokens for user-provided ServiceAccounts.
  - Rest Config Mapping: Remove the ServiceAccountRestConfigMapper, which dynamically generated rest.Config objects for impersonation.
  - Synthetic Permissions: Remove conditional logic for SyntheticPermissions that depended on impersonated clients.
This config is passed to the helm.ActionConfigGetter, ensuring that all Helm operations (install, upgrade, uninstall) use the same identity.

```
[DEPRECATION] 'spec.serviceAccount' is specified in ClusterExtension 'foo', but is ignored and will be removed in a future release.
```

## Design Details

### Test Plan

To validate the safe deprecation and eventual removal of the `.spec.serviceAccount` field, the following implementation and testing steps will be followed.

#### Unit Tests
  - Remove tests that exercised impersonation logic and ServiceAccount specific behavior.
  - Add new tests to confirm:
    - The `.spec.serviceAccount` field is ignored during reconciliation.
    - A warning is logged when the field is set.
    - Default behavior uses the controller’s own identity.

#### E2E Tests
  - Deploy `ClusterExtension` resources with and without the deprecated field.
  - Verify that:
    - Reconciliation succeeds in both cases.
    - Deprecation warnings appear in controller logs.

#### Upgrade Tests
  - CRD schema updates (required -> optional -> removed) behave safely and correctly across releases.
  - Manifests with the deprecated field do not block upgrades to 4.21 or 4.22.
  - Manifests with the field are rejected cleanly in 4.23 (removal release).
  - No reconciliation failures occur due to field removal when manifests are properly cleaned.

### Graduation Criteria / Deprecation Plan

We will deprecate the .spec.serviceAccount field over the course of three OpenShift releases following the kubernetes' deprecation policy:

OpenShift 4.20 (current release): 

OpenShift 4.21: (next release - N)

OpenShift 4.22: (N+1) 

OpenShift 4.23: (N+2) 
**Note**: Any usage of the field in manifests will cause validation errors. 

This phased approach, over the course of three releases, provides notice and a clear migration path for users to remove usage of the deprecated field safely. It gives users time to adjust and avoid disruption.

### Upgrade / Downgrade Strategy

**Upgrading to OpenShift 4.21 (deprecation  release):**

**Upgrading to OpenShift 4.23 (removal release):**

**Downgrading from 4.23 to 4.22 or earlier:**

**Downgrading from 4.22 to 4.21 or 4.20:**

### Risks and Mitigations

Deprecating and ignoring the `.spec.serviceAccount` field introduces potential risks, particularly for users who have built workflows or assumptions around impersonation-based reconciliation. Below are the primary risks, along with mitigations.

#### Risk: Unexpected Behavior for Users Relying on SA

Some users currently set `.spec.serviceAccount` assuming the controller will impersonate that ServiceAccount during reconciliation. Changing this behavior without notice could break their expectations around RBAC scopes and permissions, for example: restricting access to specific namespaces or resources.

#### Mitigation:
The controller will log a clear deprecation warning whenever a ClusterExtension includes the serviceAccount field, indicating it is now ignored and will be removed in a future release. Additionally, the field will be marked as deprecated in the CRD schema and documentation to make this clear during resource creation and review. Migration instructions will be provided in the release notes to assist users with updating their configurations.


#### Risk: Broader Permissions Required for Controller’s ServiceAccount
By removing per-resource impersonation and falling back to the controller’s default identity, the controller must operate with a broader set of permissions. This potentially violates the principle of least privilege, since the controller’s ServiceAccount may now need to access resources across multiple namespaces or API groups on behalf of all managed ClusterExtensions.

#### Mitigation:  
Although this centralizes privileges, the controller’s ServiceAccount is cluster-scoped and managed by cluster administrators. Its permissions can be restricted and audited through standard Kubernetes RBAC policies, providing clearer and simpler management compared to multiple impersonated identities. This approach aligns with common practices used by other Kubernetes controllers.


#### Risk: Potential Breaking Change for Existing Users

Some users may have been relying on the controller to impersonate the specified serviceAccount during reconciliation. Eventually removing support for this behavior may lead to unexpected changes in how permissions are applied, especially if users were using the field to restrict access.

#### Mitigation:
To ensure a smooth transition, this change will follow a deprecation process. The field will remain in the API but will be ignored by the controller. A clear warning will be logged when the field is used. After multiple releases, the field will be removed entirely from the API and CRD. This timeline gives users enough time to adapt their configurations and permissions.

## Implementation History

## Drawbacks

## Alternatives (Not Implemented)

1. Keep `.spec.serviceAccount` and Improve Token Handling  
   Instead of removing the field, we could improve token management (like automatic refresh and better error handling).  
   - However, this would add more complexity and maintenance work without fixing the main issue: impersonation is complicated and rarely helpful.

2. Create a New RBAC System for Scoped Permissions  
   Build a new way to control permissions per extension without using impersonation or ServiceAccounts (for example, by referencing ClusterRoles directly).  
   - This would make the API more complex, go against common Kubernetes practices, and could confuse users.

3. Do Nothing – Keep Supporting the Field as Is  
   - The added complexity and risks from impersonation outweigh the benefits, so leaving it unchanged is not a good option.
