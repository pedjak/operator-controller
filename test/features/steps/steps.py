import json
import os
import subprocess
from json import JSONDecodeError

from polling2 import poll
from behave import given, when, then, step
import yaml

timeout = 300
olm_namespace = "olmv1-system"


def run(cmd, stdin=None, env=None):
    try:
        if stdin is None:
            output = subprocess.check_output(
                cmd, shell=True, stderr=subprocess.STDOUT, env=env
            )
        else:
            output = subprocess.check_output(
                cmd,
                shell=True,
                stderr=subprocess.STDOUT,
                env=env,
                input=stdin.encode("utf-8"),
            )
    except subprocess.CalledProcessError as e:
        print(f"Command {cmd} failed with stderr:\n{e.output.decode('utf-8')}")
        raise e
    return output.decode("utf-8")


def apply_yaml(yaml, namespace=None):
    if namespace is not None:
        ns_arg = f"-n {namespace}"
    else:
        ns_arg = ""
    run(f"kubectl apply {ns_arg} -f -", stdin=yaml)


@given("OLM is available")
def olm_running(context):
    poll(
        lambda: run(
            f"kubectl get deployment -n {olm_namespace} operator-controller-controller-manager -o jsonpath='{{.status.conditions[?(@.type==\"Available\")].status}}'"
        )
        == "True",
        step=1,
        timeout=timeout,
    )


@given("{name} catalog serves bundles")
def catalog_serves_bundles(context, name):
    file_path = os.path.join(
        os.getcwd(), f"test/features/resources/{name}-catalog.yaml"
    )
    with open(file_path, "r") as file:
        catalog = yaml.full_load(file)
        apply_yaml(yaml.dump(catalog))
        poll(
            lambda: run(
                f"kubectl get clustercatalog {catalog['metadata']['name']} -o jsonpath='{{.status.conditions[?(@.type==\"Serving\")].status}}'"
            )
            == "True",
            step=1,
            timeout=timeout,
        )


@given("Service account {name} with needed permissions is available in namespace {ns}")
def service_account_available(context, name, ns):
    file_path = os.path.join(os.getcwd(), f"test/features/resources/rbac-template.yaml")
    with open(file_path, "r") as file:
        rbac = file.read().format(serviceaccount_name=name, namespace=ns)
        apply_yaml(rbac)


@step("ClusterExtension is applied")
def cluster_extension_present(context):
    apply_yaml(context.text)
    context.cluster_extension = yaml.full_load(context.text)["metadata"]["name"]


@step("ClusterExtension is available")
def cluster_extension_available(context):
    poll(
        lambda: run(
            f"kubectl get clusterextension {context.cluster_extension} -o jsonpath='{{.status.conditions[?(@.type==\"Installed\")].status}}'"
        )
        == "True",
        step=1,
        timeout=timeout,
    )


@step("ClusterExtension is rolled out")
def cluster_extension_installed(context):
    def _check():
        output = run(
            f"kubectl get clusterextension {context.cluster_extension} -o jsonpath='{{.status.conditions[?(@.type==\"Progressing\")]}}'"
        )
        return {
            "status": "True",
            "type": "Progressing",
            "reason": "Succeeded",
        }.items() <= json.loads(output).items()

    poll(_check, step=1, timeout=timeout, ignore_exceptions=(JSONDecodeError,))


@step("bundle {name} is installed in version {version}")
def installed_bundle(context, name, version):
    def _check():
        output = run(
            f"kubectl get clusterextension {context.cluster_extension} -o jsonpath='{{.status.install.bundle}}'"
        )
        return json.loads(output) == {"name": name, "version": version}

    poll(_check, step=1, timeout=timeout, ignore_exceptions=(JSONDecodeError,))


@then("resource {type} {name} exists in namespace {ns}")
def resource_exists(context, type, name, ns):
    poll(
        lambda: run(f"kubectl get {type} -n {ns} {name}"),
        step=1,
        timeout=timeout,
        ignore_exceptions=(subprocess.CalledProcessError,),
    )


@then(
    "ClusterExtension reports {condition_type} as {condition_status} with Reason {reason}"
)
def cluster_extension_condition_exists(
    context, condition_type, condition_status, reason
):
    def _check():
        output = run(
            f"kubectl get clusterextension {context.cluster_extension} -o jsonpath='{{.status.conditions[?(@.type==\"{condition_type}\")]}}'"
        )
        cnd = {
            "status": condition_status,
            "type": condition_type,
            "reason": reason,
        }
        if reason.endswith(":"):
            cnd["reason"] = reason[:-1]
            cnd["message"] = context.text.strip()
        return cnd.items() <= json.loads(output).items()

    poll(_check, step=1, timeout=timeout, ignore_exceptions=(JSONDecodeError,))


@when("{name} catalog is updated to version {version}")
def update_catalog(context, name, version):
    image_ref = run(
        f"kubectl get clustercatalog {name}-catalog -o jsonpath='{{.spec.source.image.ref}}'"
    )
    base_image_ref = image_ref[: image_ref.rindex(":")]
    patch = {"spec": {"source": {"image": {"ref": f"{base_image_ref}:{version}"}}}}
    run(
        f"kubectl patch clustercatalog {name}-catalog --type merge -p '{json.dumps(patch)}'"
    )
