#!/bin/bash
set -e
source "$(dirname "$0")/../config.sh"

FUNCTION_NAME="gcs-to-pubsub"
MEMORY="512Mi"
MIN_INSTANCES=0
MAX_INSTANCES=1
REGION=$LOCATION

WORKFLOW_NAME="finpipe-pipeline"

ALERT_POLICY_NAME="finpipe-function-gcs-to-pubsub-alert"

echo "[function] Deploying $FUNCTION_NAME..."
gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --project=$PROJECT_ID \
  --region=$REGION \
  --runtime="python314" \
  --source=. \
  --entry-point="process" \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=$BUCKET_LANDING" \
  --trigger-location=$REGION \
  --memory=$MEMORY \
  --timeout="30s" \
  --min-instances=$MIN_INSTANCES \
  --max-instances=$MAX_INSTANCES \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,TOPIC_ID=$PUBSUB_TOPIC,WORKFLOW_ID=$WORKFLOW_NAME,LOCATION=$REGION"
echo "[function] Done."

EXISTING_POLICY=$(gcloud alpha monitoring policies list \
    --filter="displayName=\"$ALERT_POLICY_NAME\"" \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null | head -1)

if [ -z "$EXISTING_POLICY" ]; then
    echo "[function] Creating alert policy..."
    ALERT_POLICY_FILE="/tmp/finpipe-function-alert-policy.json"
    cat > "$ALERT_POLICY_FILE" <<EOF
{
  "displayName": "$ALERT_POLICY_NAME",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Avisos e erros na Cloud Function gcs-to-pubsub",
      "conditionMatchedLog": {
        "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$FUNCTION_NAME\" AND severity=(WARNING OR ERROR)"
      }
    }
  ],
  "notificationChannels": ["$ALERT_EMAIL_CHANNEL"],
  "alertStrategy": {
    "notificationRateLimit": {
      "period": "300s"
    }
  }
}
EOF
    gcloud alpha monitoring policies create \
        --policy-from-file="$ALERT_POLICY_FILE" \
        --project=$PROJECT_ID
    rm "$ALERT_POLICY_FILE"
    echo "[function] Alert policy created."
else
    echo "[function] Alert policy already exists, skipping."
fi
