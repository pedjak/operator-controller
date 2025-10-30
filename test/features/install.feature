Feature: Install ClusterExtension

  As an OLM user I would like to install a cluster extension from catalog
  or get an appropriate information in case of an error.

  Background:
    Given OLM is available
    And test catalog serves bundles
    And Service account olm-sa with needed permissions is available in namespace foo

  Scenario: Install latest available version from the default channel
    When ClusterExtension is applied
      """
      apiVersion: olm.operatorframework.io/v1
      kind: ClusterExtension
      metadata:
        name: ce1
      spec:
        namespace: foo
        serviceAccount:
          name: olm-sa
        source:
          sourceType: Catalog
          catalog:
            packageName: test
            selector:
              matchLabels:
                "olm.operatorframework.io/metadata.name": test-catalog
            #version: 1.0.0
            #upgradeConstraintPolicy: SelfCertified
      """
    Then ClusterExtension is rolled out
    And ClusterExtension is available
    And bundle test-operator.1.2.0 is installed in version 1.2.0
    And resource networkpolicy test-operator-network-policy exists in namespace foo
    And resource configmap test-configmap exists in namespace foo
    And resource deployment test-operator exists in namespace foo


  Scenario: Report that bundle cannot be installed when exists in multiple catalogs with same priority
    Given extra catalog serves bundles
    When ClusterExtension is applied
      """
      apiVersion: olm.operatorframework.io/v1
      kind: ClusterExtension
      metadata:
        name: ce1
      spec:
        namespace: foo
        serviceAccount:
          name: olm-sa
        source:
          sourceType: Catalog
          catalog:
            packageName: test
      """
    Then ClusterExtension reports Progressing as True with Reason Retrying:
      """
      found bundles for package "test" in multiple catalogs with the same priority [extra-catalog test-catalog]
      """

