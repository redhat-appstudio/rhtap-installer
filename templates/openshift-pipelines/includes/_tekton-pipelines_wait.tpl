{{ define "rhtap.openshift-pipelines.wait" }}
echo -n "* Waiting for openshift-pipelines: "
while ! kubectl get namespace openshift-pipelines --ignore-not-found > /dev/null; do
  echo -n "."
  sleep 2
done
echo "OK"

CRDS=( pipelines tasks )
for CRD in "${CRDS[@]}"; do
  echo -n "* Waiting for '$CRD' CRD: "
  while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
    echo -n "."
    sleep 2
  done
  echo "OK"
done

echo -n "* Waiting for openshift-pipelines webhook service: "
while true; do
  # Try instanciating a task
  cat << EOF | kubectl apply -f - --dry-run=server >/dev/null 2>&1 && break
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: deleteme-task
spec:
  description: >-
    Test task to validate that Tekton is installed.
  steps:
    - image: "k8s.gcr.io/hyperkube:v1.12.1"
      name: setup
      script: |
        #!/usr/bin/env bash
        echo "OK"
      workingDir: /tmp
EOF
  echo -n "."
  sleep 2
done
echo "OK"
{{ end }}