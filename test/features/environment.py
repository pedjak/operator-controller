from behave.model_type import Status

from steps.steps import run


def after_scenario(context, scenario):
    if hasattr(context, "cluster_extension") and scenario.status == Status.passed:
        run(f"kubectl delete clusterextension {context.cluster_extension}")
