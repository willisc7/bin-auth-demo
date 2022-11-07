#!/bin/bash
PROJECT_ID=your_project_name
gcloud config set project $PROJECT_ID
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}"  --format="value(projectNumber)")
COMPUTE_SVC_ACCT=$PROJECT_NUMBER-compute@developer.gserviceaccount.com

# give default compute svc acct permission to read from and write to AR
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$COMPUTE_SVC_ACCT \
    --role=roles/artifactregistry.reader
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$COMPUTE_SVC_ACCT \
    --role=roles/artifactregistry.writer

# enable GKE to create and manage your cluster
gcloud services enable container.googleapis.com
# enable BinAuthz to manage a policy on the cluster
gcloud services enable binaryauthorization.googleapis.com
# enable KMS to manage cryptographic signing keys
gcloud services enable cloudkms.googleapis.com
# enable AR to story container images
gcloud services enable artifactregistry.googleapis.com

gcloud beta container clusters create \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
    --zone us-central1-a \
    binauthz-cluster

gcloud artifacts repositories create repo \
    --repository-format=docker \
    --location=us-central1

#set the GCR path you will use to host the container image
CONTAINER_PATH=us-central1-docker.pkg.dev/${PROJECT_ID}/repo/hello-world

#build container
docker build -t $CONTAINER_PATH ./

#push to GCR
gcloud auth configure-docker --quiet
docker push $CONTAINER_PATH

kubectl create deployment hello-world --image=$CONTAINER_PATH