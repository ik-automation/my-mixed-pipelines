local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

basic.dashboard(
  'Loose Foreign Keys Processing',
  tags=['sidekiq', 'stage_group:Sharding'],
)
.addPanels(
  layout.grid([
    basic.multiTimeseries(
      title='LooseForeignKeys::CleanupWorker runtime',
      description='How long it took for the worker to finish running. Higher is worse.',
      queries=[
        {
          legendFormat: 'Total runtime',
          query: 'sum(rate(sidekiq_jobs_completion_seconds_sum{env="$environment",worker="LooseForeignKeys::CleanupWorker"}[$__interval]))',
        },
        {
          legendFormat: 'DB runtime',
          query: 'sum(rate(sidekiq_jobs_db_seconds_sum{env="$environment",worker="LooseForeignKeys::CleanupWorker"}[$__interval]))',
        },
      ],
      yAxisLabel='Duration (seconds)'
    ),
    basic.timeseries(
      title='Processed deleted parent rows by table',
      description='How many deleted parents were processed over a time range by parent table. Higher means many deletes were occurring and being processed by the worker. A spike in this could be caused by a surge of deletes from a user.',
      query='sum(rate(loose_foreign_key_processed_deleted_records{env="$environment"}[$__interval])) by (table)',
      legendFormat='{{ table }}',
    ),
    basic.timeseries(
      title='Processed deleted child rows by table',
      description='How many child records were deleted over a time range by child table. Higher means many deletes were occurring and being processed by the worker. A spike in this could be caused by a surge of parent deletions from a user or a small number of deletes that cascaded to many child deletions.',
      query='sum(rate(loose_foreign_key_deletions{env="$environment"}[$__interval])) by (table)',
      legendFormat='{{ table }}',
    ),
    basic.timeseries(
      title='Processed updated child rows by table',
      description='How many child records were updated (nullified) over a time range by child table. Higher means many updates were occurring and being processed by the worker. A spike in this could be caused by a surge of parent deletions from a user or a small number of deletes that cascaded to many child updates.',
      query='sum(rate(loose_foreign_key_updates{env="$environment"}[$__interval])) by (table)',
      legendFormat='{{ table }}',
    ),
  ], cols=2, rowHeight=10, startRow=1)
)
