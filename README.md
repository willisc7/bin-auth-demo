# bin-auth-demo

### Prerequisites
1. Edit `setup.sh` and `setup-attestor.sh` and set `PROJECT_ID` to the name of your project

### Show a container running normally
1. `./setup.sh`
1. `kubectl get po` to show the container is running

### Apply binauth policy and show container denied from running
1. `gcloud container binauthz policy import policy.yaml`
1. Recreate the container
    ```
    kubectl delete deployment --all
    kubectl delete event --all
    kubectl create deployment hello-world --image=$CONTAINER_PATH
    ```
1. See the container was denied by the policy
    ```
    kubectl get event --template \
        '{{range.items}}{{"\033[0;36m"}}{{.reason}}:{{"\033[0m"}}{{.message}}{{"\n"}}{{end}}'
    ```

### Setup Attestor
1. `./setup-attestor.sh`
1. List Attestors `gcloud container binauthz attestors list`

### Sign the image with the Attestor's key
1. Get the digest of the image to sign
    ```
    DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:latest \
    --format='get(image_summary.digest)')
    ```
1. Create attestation for the image
    ```
    gcloud beta container binauthz attestations sign-and-create  \
        --artifact-url="${CONTAINER_PATH}@${DIGEST}" \
        --attestor="${ATTESTOR_ID}" \
        --attestor-project="${PROJECT_ID}" \
        --keyversion-project="${PROJECT_ID}" \
        --keyversion-location="${KEY_LOCATION}" \
        --keyversion-keyring="${KEYRING}" \
        --keyversion-key="${KEY_NAME}" \
        --keyversion="${KEY_VERSION}"
    ```
1. List the attestation
    ```
    gcloud container binauthz attestations list \
        --attestor=$ATTESTOR_ID --attestor-project=${PROJECT_ID}
    ```

### Run the attested image
1. Change the current policy to allow any images verified by the attestor:
    ```
    cat << EOF > updated_policy.yaml
    globalPolicyEvaluationMode: ENABLE
    defaultAdmissionRule:
      evaluationMode: REQUIRE_ATTESTATION
      enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
      requireAttestationsBy:
      - projects/${PROJECT_ID}/attestors/${ATTESTOR_ID}
    EOF
    ```
1. Update the policy: `gcloud container binauthz policy import updated_policy.yaml`
1. Run the image: `kubectl create deployment hello-world-signed --image="${CONTAINER_PATH}@${DIGEST}"`
1. See the image running: `kubectl get pods`

### Clean up
```
gcloud container clusters delete binauthz-cluster --zone us-central1-a
gcloud artifacts repositories delete repo \
    --location=us-central1
gcloud container binauthz attestors delete my-binauthz-attestor
curl -vvv -X DELETE  \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}"
```

### Credits
This repo is essentially a streamlined version of https://codelabs.developers.google.com/codelabs/cloud-binauthz-intro/#0