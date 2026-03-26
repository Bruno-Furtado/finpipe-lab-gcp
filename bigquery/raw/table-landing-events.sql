create or replace table `raw.landing_events` (
  subscription_name string options (description = 'Name of the Pub/Sub subscription that received the message'),
  message_id string options (description = 'Unique identifier assigned by Pub/Sub to the message'),
  publish_time timestamp options (description = 'Timestamp when the message was published to the Pub/Sub topic'),
  data json options (description = 'Raw message payload as JSON, base64-decoded from the Pub/Sub envelope'),
  attributes json options (description = 'Key-value metadata attributes attached to the Pub/Sub message')
)
partition by date(publish_time);
