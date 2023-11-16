# Project Dance

This helm chart installs and configures the following projects/products :


| Product | Installation    | Configuration   |
| :---:   | :---: | :---: |
| OpenShift GitOps | Operator `Subscription`   | Sets up an Argo CD in the `developer-argo` namespace for developer teams   |
| OpenShift Pipelines | Operator  `Subscription` | (TODO) Enables Tekton Chains & sets up signing keys   |
| Quay | (TODO) Operator `Subscription`  | 283   |
| ACS | (TODO)   |    |
| Trusted Application Signer | (TODO) Helm Dependency   |    |
| Trusted Profile Signer | (TODO) Helm Dependecy   |    |


# Usage

## CLI

1. Download/Clone this Git Repository
2. `helm install dance`
3. After installation completes, run a `helm list`

```
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS  CHART           APP VERSION
dance-1700077145        default         1               2023-11-15 14:39:11.764822 -0500 EST    failed  dance-0.1.0     1.16.0   
```

## UI ( a.k.a OpenShift Console )

1. Add the Helm Chart Repository to OpenShift 

```
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
  name: dance-rhtap
spec:
  connectionConfig:
    url: 'https://redhat-appstudio.github.io/helm-repository'
  name: dance
```

2. Install the Chart from the catalog

<img width="1365" alt="image" src="https://user-images.githubusercontent.com/545280/283235252-c3dfc4d7-c11b-43ff-8a52-8b1321727b3e.png">


## References


1. Helm Chart Repository https://github.com/redhat-appstudio/helm-repository 

