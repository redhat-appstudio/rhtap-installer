# Red Hat Trusted Application Pipeline

This helm chart installs and configures the following projects/products :


| Product                   | Installation                                              | Configuration                                                                                                                                                                                                            |
| :-----------------------: | :-------------------------------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| Developer Hub             | Rolled out via Helm Chart                                 | Controlled by the values YAML file.                                                                                                                                                                                      |
| OpenShift GitOps          | Operator `Subscription`                                   | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance ArgoCD will be created.                                                                     |
| OpenShift Pipelines       | Operator `Subscription`                                   | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |
| Trusted Artifact Signer   | Operator `Subscription`                                   | Default operator install & SecureSign instance                                                                                                                                                                           |
| Trusted Profile Analyzer  | Rolled out via Helm Charts `tpa-infrastructure` and `tpa` | Controlled by the values YAML file                                                                                                                                                                                       |
| Quay                      | (TODO)                                                    |                                                                                                                                                                                                                          |
| Advanced Cluster Security | (TODO)                                                    |                                                                                                                                                                                                                          |

Note: If a subscription for an operator already exists, the installation will not tamper with it. Please make sure you're using a supported version of that product. See [Compatibility matrix for 1.0](https://access.redhat.com/documentation/en-us/red_hat_trusted_application_pipeline/1.0/html/release_notes_for_red_hat_trusted_application_pipeline_1.0/con_support_matrix_default).

# Try it

## Requirements

* Helm CLI.
* An ACS endpoint and the associated API token.
* A GitHub App and its associated information (c.f. [Create a Pipelines-as-Code GitHub App](https://pipelinesascode.com/docs/install/github_apps/)).
  * `General`
    * Use placeholder values for `Homepage URL`, `Callback URL` and `Webhook URL`.
    * Generate a `Webhook secret`.
  * `Permissions & events`
    * Follow the instructions from the Pipelines-as-Code documentation.
    * `Repository permissions`
      * `Administration`: `Read and write`
* The GitHub App must be installed at the organization/user level.

## CLI

### Install
1. Login to an OpenShift 4.14 cluster.

2. Add the helm repository to your local system:

    `helm repo add rhtap https://redhat-appstudio.github.io/helm-repository`
    
    If you've already added this, run a `helm repo update` to pull the latest packages.

3. Copy `values.yaml` to `private-values.yaml`, and set your configuration parameters. You have the option to use `bin/make.sh values` to generate the configuration YAML.

4. Install/upgrade RHTAP

    `helm upgrade installer rhtap/redhat-trusted-application-pipeline --install --create-namespace --namespace rhtap --timeout 20m --values private-values.yaml`

    Sample output:
    
    ```
    NAME: installer
    LAST DEPLOYED: Fri Jan 12 12:21:01 2024
    NAMESPACE: rhtap
    STATUS: deployed
    REVISION: 1
    NOTES:
    Thank you for installing redhat-trusted-application-pipeline.
    [...]
    ```

    Run the pipeline to get the configuration information as per the `NOTES` section of the helm output.
    Use the logs information to finish the setup of the GitHub App:
    * `Homepage URL`: `.pipelines.pipelines-as-code.homepage-url`
    * `Callback URL`: `.pipelines.pipelines-as-code.callback-url`
    * `Webhook URL`: `.pipelines.pipelines-as-code.webhook-url`

### Uninstall

Note: Uninstalling RHTAP will not unsinstall any operators that were deployed during the installation.

1. Uninstall RHTAP:

    `./bin/make.sh uninstall --namespace rhtap --app-name installer`

If you do not want to use `make.sh`, perform the following actions:
1. Delete all `applications` CRs from the `rhtap` namespace.
2. Uninstall the helm chart: `helm uninstall --namespace rhtap installer`.
3. Delete the rhtap namespace.
4. Delete all the deployment namespaces (e.g. `rhtap-app-development`, `rhtap-app-production`, `rhtap-app-stage`).

## UI ( a.k.a OpenShift Console - UNSUPPORTED)

Currently unsupported as the user does not have the option to modify the default values.

# Development

## "Inner loop"

1. Download/Clone this Git Repository: `git clone https://github.com/redhat-appstudio/rhtap-installer`.
2. Install/upgrade the chart on your cluster: `./bin/make.sh apply -- --values private-values.yaml`
3. Run tests: `./test/e2e.sh -- --values private-values.yaml`

## Continuous integration

The CI is controlled by the following repositories:
* https://github.com/openshift/release
* https://github.com/redhat-appstudio/rhtap-e2e

## Release a new CI version of RHTAP

```
$ git clone https://github.com/redhat-appstudio/rhtap-installer
$ cd rhtap-installer/bin
$ ./make.sh release
```
