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
while [ "$(kubectl get pods -n openshift-pipelines -l app.kubernetes.io/name=webhook,app.kubernetes.io/part-of=tekton-pipelines --ignore-not-found | grep -c " Running ")" != "1" ]; do
  echo -n "."
  sleep 2
done
echo "OK"
{{ end }}