set -e
source "$(dirname "$0")/../config.sh"

BQ_DATASET_RAW="raw"
BQ_DATASET_SILVER="silver"
BQ_DATASET_GOLD="gold"

# --- Datasets ---
for dataset in $BQ_DATASET_RAW $BQ_DATASET_SILVER $BQ_DATASET_GOLD; do
    if bq --project_id=$PROJECT_ID ls $dataset &>/dev/null; then
        echo "[bigquery] Dataset $dataset already exists, skipping."
    else
        echo "[bigquery] Creating dataset $dataset..."
        bq --project_id=$PROJECT_ID mk \
            --dataset \
            --location=$LOCATION \
            $PROJECT_ID:$dataset
        echo "[bigquery] Dataset created."
    fi
done

# --- Tabelas raw ---
for table in landing-events; do
    if bq --project_id=$PROJECT_ID show $BQ_DATASET_RAW.${table//-/_} &>/dev/null; then
        echo "[bigquery] Table $BQ_DATASET_RAW.${table//-/_} already exists, skipping."
    else
        echo "[bigquery] Creating table $BQ_DATASET_RAW.${table//-/_}..."
        bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
            "$(cat "$(dirname "$0")/raw/table-${table}.sql")"
        echo "[bigquery] Table created."
    fi
done

# --- Funções silver ---
echo "[bigquery] Creating/updating silver functions..."
bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
    "$(cat "$(dirname "$0")/silver/funcs.sql")"
echo "[bigquery] Silver functions done."

# --- Tabelas silver ---
for table in transactions customers; do
    if bq --project_id=$PROJECT_ID show $BQ_DATASET_SILVER.$table &>/dev/null; then
        echo "[bigquery] Table $BQ_DATASET_SILVER.$table already exists, skipping."
    else
        echo "[bigquery] Creating table $BQ_DATASET_SILVER.$table..."
        bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
            "$(cat "$(dirname "$0")/silver/table-${table}.sql")"
        echo "[bigquery] Table created."
    fi
done

# --- Procedures silver ---
echo "[bigquery] Creating/updating silver procedures..."
for proc in transactions customers; do
    bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
        "$(cat "$(dirname "$0")/silver/proc-${proc}.sql")"
    echo "[bigquery] Procedure silver/proc-${proc} done."
done

# --- Tabelas gold ---
for table in transactions; do
    if bq --project_id=$PROJECT_ID show $BQ_DATASET_GOLD.$table &>/dev/null; then
        echo "[bigquery] Table $BQ_DATASET_GOLD.$table already exists, skipping."
    else
        echo "[bigquery] Creating table $BQ_DATASET_GOLD.$table..."
        bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
            "$(cat "$(dirname "$0")/gold/table-${table}.sql")"
        echo "[bigquery] Table created."
    fi
done

# --- Procedures gold ---
echo "[bigquery] Creating/updating gold procedures..."
bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
    "$(cat "$(dirname "$0")/gold/proc-transactions.sql")"
echo "[bigquery] Procedure gold/proc-transactions done."

# --- Views gold ---
echo "[bigquery] Creating/updating gold views..."
for view in transactions-monthly-ttm transactions-daily-avg-price transactions-customers-last-quarter; do
    bq --project_id=$PROJECT_ID query --use_legacy_sql=false \
        "$(cat "$(dirname "$0")/gold/view-${view}.sql")"
    echo "[bigquery] View gold/view-${view} done."
done

echo "[bigquery] Done."
