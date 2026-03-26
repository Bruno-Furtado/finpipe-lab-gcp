"""
Cloud Run Function: GCS to Pub/Sub
Disparada pelo EventArc quando um arquivo CSV é enviado ao bucket.
Lê o CSV e publica todos os rows como uma única mensagem no Pub/Sub.
"""

import csv
import io
import json
import logging
import os
import uuid
from datetime import UTC, datetime

import functions_framework
from cloudevents.http import CloudEvent
from google.cloud import pubsub_v1, storage
from google.cloud.workflows import executions_v1

PROJECT_ID = os.environ['PROJECT_ID']
TOPIC_ID = os.environ['TOPIC_ID']
WORKFLOW_ID = os.environ['WORKFLOW_ID']
LOCATION = os.environ['LOCATION']
ENTITIES = {'transactions', 'customers'}


class _JsonFormatter(logging.Formatter):
	_EXTRAS = ('audit_id', 'entity', 'file')

	def format(self, record: logging.LogRecord) -> str:
		entry = {'severity': record.levelname, 'message': record.getMessage()}
		if record.exc_info:
			entry['error'] = self.formatException(record.exc_info)
		entry.update({k: v for k in self._EXTRAS if (v := getattr(record, k, None)) is not None})
		return json.dumps(entry, ensure_ascii=False)


_handler = logging.StreamHandler()
_handler.setFormatter(_JsonFormatter())
logging.basicConfig(level=logging.INFO, handlers=[_handler], force=True)
logger = logging.getLogger(__name__)

storage_client = storage.Client()
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
executions_client = executions_v1.ExecutionsClient()


def _resolve_entity(file_path: str) -> str | None:
	for entity in ENTITIES:
		if file_path.startswith(f'entity={entity}/'):
			return entity
	return None


def _read_csv_from_gcs(bucket_name: str, file_path: str) -> list[dict]:
	blob = storage_client.bucket(bucket_name).blob(file_path)
	return list(csv.DictReader(io.StringIO(blob.download_as_text(encoding='utf-8'))))


def _publish_rows(rows: list[dict], entity: str, file_path: str, file_name: str, audit_id: str) -> None:
	message = json.dumps(rows, ensure_ascii=False).encode('utf-8')
	attributes = {
		'audit_id': audit_id,
		'entity': entity,
		'source_path': file_path,
		'source_file': file_name,
		'ingested_at': datetime.now(UTC).isoformat(),
	}
	publisher.publish(topic_path, data=message, **attributes).result()


def _trigger_workflow(audit_id: str, entity: str) -> None:
	parent = f'projects/{PROJECT_ID}/locations/{LOCATION}/workflows/{WORKFLOW_ID}'
	execution = executions_v1.Execution(
		argument=json.dumps({'audit_id': audit_id, 'entity': entity})
	)
	executions_client.create_execution(parent=parent, execution=execution)


@functions_framework.cloud_event
def process(cloud_event: CloudEvent) -> None:
	audit_id = str(uuid.uuid4())
	bucket_name = cloud_event.data['bucket']
	file_path = cloud_event.data['name']
	file_name = file_path.split('/')[-1]
	ctx = {'audit_id': audit_id, 'file': file_path}

	if not file_path.endswith('.csv'):
		logger.info('File ignored (not CSV): %s', file_path, extra=ctx)
		return

	entity = _resolve_entity(file_path)
	if not entity:
		logger.warning('Unknown entity: %s', file_path, extra=ctx)
		return

	ctx['entity'] = entity
	logger.info('Starting: entity=%s file=%s', entity, file_name, extra=ctx)

	try:
		rows = _read_csv_from_gcs(bucket_name, file_path)
	except Exception:
		logger.error('Failed to read CSV: gs://%s/%s', bucket_name, file_path, exc_info=True, extra=ctx)
		raise

	try:
		_publish_rows(rows, entity, file_path, file_name, audit_id)
	except Exception:
		logger.error('Failed to publish to Pub/Sub: entity=%s file=%s', entity, file_name, exc_info=True, extra=ctx)
		raise

	try:
		_trigger_workflow(audit_id, entity)
	except Exception:
		logger.warning('Failed to trigger workflow: entity=%s file=%s', entity, file_name, exc_info=True, extra=ctx)
		return

	logger.info('Done: %d rows | entity=%s | file=%s', len(rows), entity, file_name, extra=ctx)
