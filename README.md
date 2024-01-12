# Red Hat Trusted Application Pipeline

This helm chart installs and configures the following projects/products :


| Product | Installation    | Configuration   |
| :---:   | :---: | :---: |
| OpenShift GitOps | Operator `Subscription`   | Sets up an Argo CD in the `developer-argo` namespace for developer teams   |
| OpenShift Pipelines | Operator  `Subscription` | (TODO) Enables Tekton Chains & sets up signing keys   |
| Quay | (TODO) Operator `Subscription`  |    |
| ACS | (TODO)   |    |
| Trusted Artifact Signer | (TODO) Helm Dependency   |    |
| Trusted Profile Analyzer | (TODO) Helm Dependecy   |    |


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

0. Login to an OpenShift 4.14 cluster and create a new Project.

1. Add the helm repository to your local system 

    `helm repo add rhtap https://redhat-appstudio.github.io/helm-repository`
    
    If you've already added this, run a `helm repo update` time to time to pull the latest packages.

2. Edit `values.yaml` to set your configuration parameters.

3. Install/upgrade RHTAP

    `helm upgrade installer rhtap/rhtap --install --create-namespace --namespace rhtap --values values.yaml`

    Sample output:
    
    ```
    NAME: installer
    LAST DEPLOYED: Fri Jan 12 12:21:01 2024
    NAMESPACE: rhtap
    STATUS: deployed
    REVISION: 1
    NOTES:
    Thank you for installing rhtap-installer.
    [...]
    ```

    Run the pipeline to get the configuration information as per the `NOTES` section of the helm output.
    Use the logs information to finish the setup of the GitHub App:
    * `Homepage URL`: `.pipelines.pipelines-as-code.homepage-url`
    * `Callback URL`: `.pipelines.pipelines-as-code.callback-url`
    * `Webhook URL`: `.pipelines.pipelines-as-code.webhook-url`

3. Uninstall RHTAP

    `helm uninstall --namespace rhtap installer`

## UI ( a.k.a OpenShift Console )

1. Add the Helm Chart Repository to OpenShift 

```
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
  name: rhtap-installer
spec:
  connectionConfig:
    url: 'https://redhat-appstudio.github.io/helm-repository'
  name: rhtap-installer
```

2. Install the Chart from the catalog

<img width="1365" alt="image" src="https://user-images.githubusercontent.com/545280/283235252-c3dfc4d7-c11b-43ff-8a52-8b1321727b3e.png">



## Development

### "Inner loop"

1. Download/Clone this Git Repository: `git clone https://github.com/redhat-appstudio/rhtap-installer`.
2. Install/upgrade the chart on your cluster: `./bin/make.sh apply -- --values values-private.yaml`
3. Run tests: `./test/e2e.sh -- --values values-private.yaml`

### Continuous integration

TODO

### Release a new version of RHTAP

```
$ git clone https://github.com/redhat-appstudio/rhtap-installer
$ cd rhtap-installer/bin
$ ./make.sh release
```
