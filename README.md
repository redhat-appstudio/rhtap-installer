# Project Dance

This helm chart installs and configures the following projects :

* Red Hat OpenShift GitOps
* Red Hat OpenShift Pipelines
* Red Hat Quay
* Red Hat ACS


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

