{{ define "dance.includes.tektonconfig" }}
{
  "spec": {
    "pipeline": {
      "enable-bundles-resolver": true,
      "enable-cluster-resolver": true,
      "enable-custom-tasks": true,
      "enable-git-resolver": true,
      "enable-hub-resolver": true,
      "enable-tekton-oci-bundles": true
    }
  }
}
{{ end }}