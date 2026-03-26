set -e
source "$(dirname "$0")/../config.sh"

PUBSUB_TOPIC_DLT="finpipe-landing-events-dlq"
PUBSUB_SUBSCRIPTION="finpipe-landing-events-bq-sub"
PUBSUB_RETENTION="7d"
PUBSUB_MAX_DELIVERY_ATTEMPTS=5

BQ_DATASET_RAW="raw"
BQ_TABLE_RAW="landing_events"

ALERT_POLICY_NAME="finpipe-pubsub-dlq-alert"

# Main topic
if gcloud pubsub topics describe $PUBSUB_TOPIC --project=$PROJECT_ID &>/dev/null; then
    echo "[pubsub] Topic $PUBSUB_TOPIC already exists, skipping."
else
    echo "[pubsub] Creating topic $PUBSUB_TOPIC..."
    gcloud pubsub topics create $PUBSUB_TOPIC --project=$PROJECT_ID
    echo "[pubsub] Topic created."
fi

# Dead Letter Topic
if gcloud pubsub topics describe $PUBSUB_TOPIC_DLT --project=$PROJECT_ID &>/dev/null; then
    echo "[pubsub] Dead letter topic $PUBSUB_TOPIC_DLT already exists, skipping."
else
    echo "[pubsub] Creating dead letter topic $PUBSUB_TOPIC_DLT..."
    gcloud pubsub topics create $PUBSUB_TOPIC_DLT \
        --message-retention-duration=$PUBSUB_RETENTION \
        --project=$PROJECT_ID
    echo "[pubsub] Dead letter topic created."
fi

# Subscription BigQuery
if gcloud pubsub subscriptions describe $PUBSUB_SUBSCRIPTION --project=$PROJECT_ID &>/dev/null; then
    echo "[pubsub] Subscription $PUBSUB_SUBSCRIPTION already exists, skipping."
else
    echo "[pubsub] Creating BigQuery subscription $PUBSUB_SUBSCRIPTION..."
    gcloud pubsub subscriptions create $PUBSUB_SUBSCRIPTION \
        --topic=$PUBSUB_TOPIC \
        --bigquery-table=$PROJECT_ID:$BQ_DATASET_RAW.$BQ_TABLE_RAW \
        --write-metadata \
        --message-retention-duration=$PUBSUB_RETENTION \
        --dead-letter-topic=$PUBSUB_TOPIC_DLT \
        --max-delivery-attempts=$PUBSUB_MAX_DELIVERY_ATTEMPTS \
        --project=$PROJECT_ID
    echo "[pubsub] Subscription created."
fi

# Cloud Monitoring Alert
EXISTING_POLICY=$(gcloud alpha monitoring policies list \
    --filter="displayName=\"$ALERT_POLICY_NAME\"" \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null | head -1)

if [ -z "$EXISTING_POLICY" ]; then
    echo "[pubsub] Creating alert policy for dead letter topic..."
    ALERT_POLICY_FILE="/tmp/finpipe-alert-policy.json"
    cat > "$ALERT_POLICY_FILE" <<EOF
{
  "displayName": "$ALERT_POLICY_NAME",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Undelivered messages in subscription",
      "conditionThreshold": {
        "filter": "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND resource.type=\"pubsub_subscription\" AND resource.label.\"subscription_id\"=\"$PUBSUB_SUBSCRIPTION\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0,
        "duration": "60s"
      }
    }
  ],
  "notificationChannels": ["$ALERT_EMAIL_CHANNEL"]
}
EOF
    gcloud alpha monitoring policies create \
        --policy-from-file="$ALERT_POLICY_FILE" \
        --project=$PROJECT_ID
    rm "$ALERT_POLICY_FILE"
    echo "[pubsub] Alert policy created."
else
    echo "[pubsub] Alert policy already exists, skipping."
fi

echo "[pubsub] Done."
