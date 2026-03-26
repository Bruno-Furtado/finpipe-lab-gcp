set -e
source "$(dirname "$0")/../config.sh"

if gcloud storage buckets describe gs://$BUCKET_LANDING --project=$PROJECT_ID &>/dev/null; then
    echo "[storage] Bucket $BUCKET_LANDING already exists, skipping."
else
    echo "[storage] Creating bucket $BUCKET_LANDING..."
    gcloud storage buckets create gs://$BUCKET_LANDING \
        --project=$PROJECT_ID \
        --default-storage-class=STANDARD \
        --location=$LOCATION \
        --uniform-bucket-level-access \
        --public-access-prevention
    echo "[storage] Done."
fi
