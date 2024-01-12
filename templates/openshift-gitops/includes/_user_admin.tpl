{{ define "rhtap.argocd.user_admin" }}
{
  "spec": {
    "extraConfig": {
      "admin.enabled": "false"
    }
  }
}
{{ end }}