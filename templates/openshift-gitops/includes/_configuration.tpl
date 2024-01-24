{{ define "rhtap.argocd.configuration" }}
{
  "spec": {
    "server": {
      "route":{
        "tls": {
          "insecureEdgeTerminationPolicy": "Redirect",
          "termination": "reencrypt"
        }
      }
    },
    "extraConfig": {
      "accounts.admin": "apiKey, login"
    }
  }
}
{{ end }}