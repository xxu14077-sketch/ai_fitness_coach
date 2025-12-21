-- Add unique constraint to body_metrics to enable proper upsert
alter table body_metrics
  add constraint body_metrics_user_date_key unique (user_id, date);

-- Add unique constraint to strength_progress to enable proper upsert
alter table strength_progress
  add constraint strength_progress_user_date_exercise_key unique (user_id, date, exercise);
