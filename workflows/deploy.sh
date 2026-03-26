#!/bin/bash
set -e
source "$(dirname "$0")/../config.sh"

WORKFLOW_NAME="finpipe-pipeline"

SA_NAME="finpipe-workflow-sa"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" --project=$PROJECT_ID &>/dev/null; then
  echo "[workflows] Service account $SA_NAME already exists, skipping creation and role bindings."
else
  echo "[workflows] Creating service account $SA_NAME..."
  gcloud iam service-accounts create $SA_NAME \
    --display-name="FinPipe Workflow SA" \
    --project=$PROJECT_ID

  echo "[workflows] Granting roles..."
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.jobUser"

  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.dataEditor"
fi

echo "[workflows] Deploying workflow $WORKFLOW_NAME..."
gcloud workflows deploy $WORKFLOW_NAME \
  --location=$LOCATION \
  --source="$(dirname "$0")/pipeline.yaml" \
  --service-account=$SA_EMAIL \
  --project=$PROJECT_ID

echo "[workflows] Done. Workflow ID: $WORKFLOW_NAME"
