PROJECT_ID="finpipe-lab"
LOCATION="us-central1"
PUBSUB_TOPIC="finpipe-landing-events"

ALERT_EMAIL="brunotfurtado@gmail.com"
ALERT_CHANNEL_NAME="finpipe-alert-email"

BUCKET_LANDING="finpipe-landing"

ALERT_EMAIL_CHANNEL=$(gcloud alpha monitoring channels list \
    --filter="displayName=\"$ALERT_CHANNEL_NAME\"" \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null | head -1)
if [ -z "$ALERT_EMAIL_CHANNEL" ]; then
    ALERT_EMAIL_CHANNEL=$(gcloud alpha monitoring channels create \
        --display-name="$ALERT_CHANNEL_NAME" \
        --type=email \
        --channel-labels=email_address=$ALERT_EMAIL \
        --project=$PROJECT_ID \
        --format="value(name)")
fi
