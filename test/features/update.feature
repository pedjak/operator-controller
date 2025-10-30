Feature: Update ClusterExtension

  As an OLM user I would like to update a ClusterExtension from a catalog
  or get an appropriate information in case of an error.

  Background:
    Given OLM is available
    And test catalog serves bundles
    And Service account olm-sa with needed permissions is available in namespace foo

  Scenario: Update to a successor version
    Given ClusterExtension is applied
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
            version: 1.0.0
      """
    And ClusterExtension is rolled out
    And ClusterExtension is available
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
            version: 1.0.1
      """
    Then ClusterExtension is rolled out
    And ClusterExtension is available
    And bundle test-operator.1.0.1 is installed in version 1.0.1

  Scenario: Cannot update extension to non successor version
    Given ClusterExtension is applied
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
            version: 1.0.0
      """
    And ClusterExtension is rolled out
    And ClusterExtension is available
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
            version: 1.2.0
      """
    Then ClusterExtension reports Progressing as True with Reason Retrying:
      """
      error upgrading from currently installed version "1.0.0": no bundles found for package "test" matching version "1.2.0"
      """

  Scenario: Force update to non successor version
    Given ClusterExtension is applied
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
            version: 1.0.0
      """
    And ClusterExtension is rolled out
    And ClusterExtension is available
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
            version: 1.2.0
            upgradeConstraintPolicy: SelfCertified
      """
    Then ClusterExtension is rolled out
    And ClusterExtension is available
    And bundle test-operator.1.2.0 is installed in version 1.2.0

  Scenario: Auto update when new version becomes available in catalog
    Given ClusterExtension is applied
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
      """
    And ClusterExtension is rolled out
    And ClusterExtension is available
    And bundle test-operator.1.2.0 is installed in version 1.2.0
    When test catalog is updated to version v2
    Then bundle test-operator.1.3.0 is installed in version 1.3.0