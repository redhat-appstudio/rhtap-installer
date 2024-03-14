{{ define "rhtap.includes.tektonconfig" }}
{
  "spec": {
    "pipeline": {
      "enable-bundles-resolver": true,
      "enable-cluster-resolver": true,
      "enable-custom-tasks": true,
      "enable-git-resolver": true,
      "enable-hub-resolver": true,
      "enable-tekton-oci-bundles": true
    },
    "chain": {
      "artifacts.oci.storage": "oci",
      "artifacts.pipelinerun.format": "in-toto",
      "artifacts.pipelinerun.storage": "oci",
      "artifacts.taskrun.format": "in-toto",
      "artifacts.taskrun.storage": "oci",
      "transparency.enabled": "true",
      "transparency.url": "http://rekor-server.{{.Release.Namespace}}.svc"
    }
  }
}
{{ end }}
