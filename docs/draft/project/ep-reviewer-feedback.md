# EP #1860 Reviewer Feedback Reference

Inline comments from the closed [EP #1860](https://github.com/openshift/enhancements/pull/1860)
and top-level discussion comments, organized by EP section.

---

## Frontmatter / Process

### everettraven
> Note, there should generally be one approver that is responsible for helping drive to consensus amongst the set of stakeholders (generally represented in the reviewers section). With multiple approvers it gets difficult to know who is responsible for actually helping to get this "over the line". The approver should generally be someone from your team, usually a team lead or a staff engineer. I should also be placed under a specific subgroup of approvers called `api-approvers`.

### JoelSpeed
> As far as I can tell, we should still be following the EP process for this change. Especially given your phase 0 seems to be exactly the same as what the proposal here was suggesting and that is something we have already been discussing as a no go.

---

## Summary / Motivation

### everettraven — on "limited benefit" claim
> It would be helpful if you could clarify what the "limited benefit" here is. You start this section talking about how the intention was originally for following a least-privilege principle which, on the surface, sounds like it would actually be a pretty big benefit. After all, looking at the documentation for OLMv1 it seems like "secure by default" is a core tenet. As a reviewer, I'd like to better understand:
> - Why this tenet was originally seen as a win for end users
> - Why this tenet turned out to _not_ be a win for end users

### everettraven — on "rarely helpful"
> Reading through this, I'm not convinced on the "rarely helpful" part. Please do update this document appropriately to explicitly state _why_ this has been found to be rarely helpful.

### everettraven — on complexity claims
> Reading through this, I still don't have a solid understanding of how painful this added complexity and risks of impersonation actually are.

### everettraven — on boxcutter requiring cluster-admin
> Why do you specifically need to use boxcutter for a revision rollout approach? What are the limitations in doing revision rollouts, regardless of underlying implementation, that makes it impossible for you to continue to adhere to the least-privilege principle?

### everettraven — on active issues with current implementation
> Are you actively experiencing issues with being able to handle these scenarios? From what I remember this logic is all already implemented and is flexed during testing. I'm curious how many times the logic to do these things have been problematic from both an end-user perspective and a maintenance perspective.

### grokspawn — on boxcutter motivation
> I'd understood that it also arose from the need to implement a rollout revision approach (using boxcutter) which required cluster admin permissions anyway, so we couldn't reasonably reduce the privileges of a "package manager" from cluster admin levels.

---

## Proposal / API Changes

### everettraven — on `x-kubernetes-deprecated`
> I don't think this exists? As far as I am aware, there is not yet a way to mark a specific field in a CRD schema as deprecated. https://pkg.go.dev/k8s.io/apiextensions-apiserver/pkg/apis/apiextensions#JSONSchemaProps would be your canonical source of things you can set for a particular schema property.

### grokspawn — on `x-kubernetes-deprecated`
> Looks like maybe it hasn't landed yet: https://github.com/kubernetes/kubernetes/issues/131817. So the only option is to comment that these are deprecated (in addition to programmatic capture of "a deprecated thing is being used").

### everettraven — on VAP suggestion
> You could include a validating admission policy that issues a warning on admission of `ClusterExtension` resources that have that field set.

### everettraven — on XValidation marker
> I don't believe this is a valid marker. I'm pretty certain that a `rule` is required and if it fails validation will not be a warning but instead will block admission of the resource — which is not something I think you want to do here.

### everettraven — on pointer vs omitzero
> Beforehand, was an empty string (`""`) a valid value here?

### grokspawn — on omitzero
> We considered moving this to a pointer type to be a potentially breaking change we could avoid, so we're using go1.24's `omitzero` capability to omit this field from the struct if it is set to only 'default' values.

### everettraven — on API version
> This is a GA'd and stable API right?
> ```suggestion
> apiVersion: olm.operatorframework.io/v1
> ```

### grokspawn — on empty string validity
> No. It would've failed the [DNS1123 label check](https://github.com/operator-framework/operator-controller/blob/main/api/v1/clusterextension_types.go#L400).

---

## Proposal / Controller Logic Changes

### everettraven — on deprecated fields should still function
> Generally, deprecated fields should still function as-is until they are fully removed. You may have existing users that are expecting that behavior to function in that manner and changing that behavior out from under them is a breaking change.

### everettraven — on Synthetic Permissions
> How do "Synthetic Permissions" play a role in service account based permissions? What are "Synthetic Permissions"?

### grokspawn — on deprecation metrics
> I think we need to adopt an approach similar to how k8s tracks deprecation (see: https://kubernetes.io/blog/2020/09/03/warnings/#metrics). For example, we could implement a `clusterextension_requested_deprecated_api` metric, or an admission webhook to warn when we try to create a ClusterExtension with a serviceaccount.

---

## Proposal / Preflight Permissions

### grokspawn — on preflight removal scope
> Do we need to include the removal of the preflight permissions checks here, or is that not required because those are not GA'd?

---

## Risks and Mitigations

### everettraven — on privilege escalation via automatic upgrades
> What about the risk of an automatic upgrade going through that performs privilege escalation of an installed operator? If that automatic upgrade happens to upgrade to a version that has some malicious code in it, giving OLM cluster admin means that it will stamp out whatever the installation manifests require and could lead to a direct injection of a malicious actor into a production environment.

### everettraven — on OLM as injection vector
> This could certainly be considered a drawback to increase the permissions associated with the OLM Service Account, but I think a bigger drawback I don't see explicitly mentioned here is the potential for OLM to be _the thing_ that injected a malicious actor into the cluster because it no longer will fail to stamp out permissions it wasn't explicitly told it could. While it may still be difficult, we've seen in the past malicious actors sneak something into a popular project that is then shipped out en masse. With this change, OLM could be used to get that access to a cluster.

### everettraven — on managing controller permissions
> How do they carefully manage the controller's permissions? You are dictating that it must be cluster admin.

### grokspawn — on lost signal for upgrade permissions
> Lost signal if an operator upgrade requires permissions not provided by the existing, configured serviceaccount (since OLMv1 can do anything, we might perpetrate the upgrade and then have the operator fail).

---

## Graduation Criteria / Deprecation Plan

### grokspawn — on graduation discussion
> I think the graduation plan is a good place to discuss this, and maybe I'm just imagining that we're going to end up having a lively discussion on the path forward and not wanting to have to update two places.

### grokspawn — on GA'd API removal
> Here's where we really need arch guidance. We've been informed that GA'd OCP APIs have functionally never been removed, even though nominally we could — after a reasonable period — up-version the API and remove the field, including a conversion webhook to handle upgrades.

### everettraven — on API version removal process
> I'm not 100% sure what our process here for an up-version of an API is in OpenShift, but if there is one, I imagine it wouldn't be too dissimilar from Kubernetes. You cannot remove the API version until it has "aged out". As far as I know, OpenShift has _never_ removed a stable API version so I would default to not being able to do this. I know OLM is an upstream project that we sync the APIs downstream, and we generally aren't as restrictive there because we don't entirely control the API surface, but IIUC we consider OLM a core component of the OpenShift payload so I would expect that we end up treating it with a bit more caution.

---

## Upgrade / Downgrade Strategy

### everettraven — on downgrade handling
> How would a downgrade handle the case where the field was previously required but is now optional and as such may not be present?

### everettraven — on enforcing field removal before upgrade
> How are you planning to enforce that the field is not present in any instances of the resource prior to upgrading?

### everettraven — on older client compatibility
> Do you care about breaking older clients that are readers of your API that would have expected that the `serviceAccount` field is _always_ set? If you want to maintain compatibility with older clients that read your API you'd need to default this field as well to a valid default value.

---

## Alternatives

### everettraven — on missing alternatives
> Some alternatives I've not seen mentioned as being considered. Curious if you've thought of them:
> - Building better client tooling that makes managing permission requirements easier for users looking to install cluster extensions.
> - Building a permission requesting system that makes it easier for users to request installation of a cluster extension and OLM creating a "permission request" that an admin can either approve or deny to automatically stamp out the RBAC needed to complete the installation.

### JoelSpeed — on three-path approach
> In the call on tuesday, we talked about how we will have users who want this level of granularity. I was under the impression at the end that deprecating was not the intent, but allowing users three paths (not specifying at all, specifying but use a namespace bound admin (with some cluster roles), go the full secure least privilege route) was where we were headed? For that, we need to fix the existing issues that exist with the field, namely privilege escalation and UX.
>
> I've suggested in the RFC a relatively straightforward and secure approach to solving the privilege escalation issue.
>
> The other issue is the UX, which we still need to discuss how to improve, I was prompting in the RFC for further details on this so that we could continue the conversation.

### JoelSpeed — on deprecation without replacement
> I don't think we can do this until we have something new to point users to that replaces this. How far off is that?

---

## Rashmigottipati's closing phased plan

> **Phase 0: 4.21 Prep / Deprecation** — Deprecate spec.serviceAccount field and turn it into an optional field. If set by the user, it should function exactly how it works currently.
>
> **Phase 1: Clean-up/Preflight Removal** — Remove permissions preflight checks, remove synthetic authentication.
>
> **Phase 2: Impersonation** — Switch to using the impersonation API instead of ServiceAccount tokens.
>
> **Phase 3: Future/Boxcutter Integration** — Revisit the CE ServiceAccount handling after Boxcutter and Helm support is integrated.
