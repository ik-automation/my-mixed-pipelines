local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local statPanel = grafana.statPanel;
local gaugePanel = grafana.gaugePanel;
local promQuery = import 'grafana/prom_query.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';

local queueSizeTresholds = [
  { color: colorScheme.normalRangeColor, value: 0 },
  { color: colorScheme.warningColor, value: 5000 },
  { color: colorScheme.errorColor, value: 10000 },
  { color: colorScheme.criticalColor, value: 50000 },
];

basic.dashboard(
  'Garbage Collection Detail',
  tags=['container registry', 'docker', 'registry'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-registry,',
    'gitlab-registry',
    hide='variable',
  )
)
.addTemplate(template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(registry_gc_runs_total{environment="$environment"}, cluster)',
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanel(
  row.new(title='Overview'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    statPanel.new(
      title='Queued Tasks',
      description='The most recent number of tasks queued for review.',
      graphMode='none',
      reducerFunction='last',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        'sum(avg by (query_name) (last_over_time(gitlab_database_rows{query_name=~"registry_gc_.*_review_queue", environment="$environment"}[$__interval])))',
      )
    ),
    statPanel.new(
      title='Pending Tasks',
      description='The most recent number of tasks ready for review.',
      graphMode='none',
      reducerFunction='last',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        'sum(avg by (query_name) (last_over_time(gitlab_database_rows{query_name=~"registry_gc_.*_review_queue_overdue", environment="$environment"}[$__interval])))',
      )
    )
    .addThresholds(queueSizeTresholds),
    statPanel.new(
      title='Processed Tasks',
      description='The total number of processed tasks.',
      graphMode='none',
      reducerFunction='sum',
      unit='short',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval]))',
      )
    ),
    statPanel.new(
      title='Dangling',
      description='The percentage of tasks that target a dangling artifact.',
      graphMode='none',
      unit='percentunit',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        |||
          (
            sum(rate(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster", error="false", noop="false", dangling="true"}[$__interval]))
            /
            sum(rate(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster", error="false", noop="false"}[$__interval]))
          )
        |||,
      )
    ),
    statPanel.new(
      title='Deletions',
      description='The total number of deletions (manifests and blobs).',
      graphMode='none',
      reducerFunction='sum',
      unit='short',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_gc_deletes_total{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval]))',
      )
    ),
    statPanel.new(
      title='Uploaded Bytes',
      description='The number of bytes uploaded to the new code path.',
      graphMode='none',
      reducerFunction='sum',
      unit='bytes',
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_storage_blob_upload_bytes_sum{environment="$environment", stage="$stage", migration_path="new"}[$__interval]))',
      )
    ),
    statPanel.new(
      title='Recovered Storage Space',
      description='The number of bytes recovered by online GC.',
      graphMode='none',
      reducerFunction='sum',
      unit='bytes',
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_gc_storage_deleted_bytes_total{environment="$environment", stage="$stage"}[$__interval]))',
      )
    ),
    statPanel.new(
      title='Median Analysis Latency',
      description=|||
        The aggregated P50 latency of the database queries used to determine if
        a blob or manifest are eligible for deletion (dangling).
      |||,
      graphMode='none',
      decimals=2,
      unit='s',
    )
    .addTarget(
      promQuery.target(
        |||
          histogram_quantile(0.5,
            sum by (le) (
              rate(registry_database_query_duration_seconds_bucket{name=~"gc_.*_task_is_dangling", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
            )
          )
        |||,
      )
    )
    .addThresholds([
      { color: colorScheme.normalRangeColor, value: 0.025 },
      { color: colorScheme.warningColor, value: 0.05 },
      { color: colorScheme.criticalColor, value: 0.1 },
    ]),
    statPanel.new(
      title='Median Delete Latency (Database)',
      description='The aggregated P50 latency of the database delete queries.',
      graphMode='none',
      decimals=2,
      unit='s',
    )
    .addTarget(
      promQuery.target(
        |||
          histogram_quantile(0.5,
            sum by (le) (
              rate(registry_gc_delete_duration_seconds_bucket{backend="database", error="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
            )
          )
        |||,
      )
    )
    .addThresholds([
      { color: colorScheme.normalRangeColor, value: 0.025 },
      { color: colorScheme.warningColor, value: 0.05 },
      { color: colorScheme.criticalColor, value: 0.1 },
    ]),
    statPanel.new(
      title='Median Delete Latency (Storage)',
      description='The aggregated P50 latency of the storage delete requests.',
      graphMode='none',
      decimals=2,
      unit='s',
    )
    .addTarget(
      promQuery.target(
        |||
          histogram_quantile(0.5,
            sum by (le) (
              rate(registry_gc_delete_duration_seconds_bucket{backend="storage", error="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
            )
          )
        |||,
      )
    )
    .addThresholds([
      { color: colorScheme.normalRangeColor, value: 0.250 },
      { color: colorScheme.warningColor, value: 0.500 },
      { color: colorScheme.criticalColor, value: 0.750 },
    ]),
    gaugePanel.new(
      title='Successfull Runs',
      description='The percentage of online GC runs that completed without error.',
    )
    .addTarget(
      promQuery.target(
        |||
          (
            sum(rate(registry_gc_runs_total{error="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval]))
            /
            sum(rate(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval]))
          ) * 100
        |||,
      )
    )
    .addThresholds([
      { color: colorScheme.criticalColor, value: 50 },
      { color: colorScheme.errorColor, value: 75 },
      { color: colorScheme.warningColor, value: 95 },
      { color: colorScheme.normalRangeColor, value: 100 },
    ]),
  ], cols=11, rowHeight=4, startRow=1)
)

.addPanel(
  row.new(title='Queues'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Queued Tasks',
      description='The number of tasks queued for review.',
      query='avg by (query_name) (gitlab_database_rows{query_name=~"registry_gc_.*_review_queue", environment="$environment"})',
      legendFormat='{{ query_name }}',
      intervalFactor=1,
      yAxisLabel='Count'
    ),
    basic.timeseries(
      title='Pending Tasks',
      description='The number of tasks ready for review.',
      query='avg by (query_name) (gitlab_database_rows{query_name=~"registry_gc_.*_review_queue_overdue", environment="$environment"})',
      legendFormat='{{ query_name }}',
      intervalFactor=1,
      yAxisLabel='Count'
    ),
    basic.timeseries(
      title='Postponed Tasks',
      description=|||
        The number of tasks whose review was postponed due processing errors.
      |||,
      query='sum by (worker) (registry_gc_postpones_total{environment="$environment"})',
      legendFormat='{{ worker }}',
      yAxisLabel='Count'
    ),
    basic.timeseries(
      title='Time Between Reviews',
      description=|||
        The median time between task reviews. This is the workers' sleep duration
        between runs.
      |||,
      query=|||
        histogram_quantile(0.50,
          sum by (worker, le) (
            rate(registry_gc_sleep_duration_seconds_bucket{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ worker }}',
      format='s'
    ),
  ], cols=4, rowHeight=10, startRow=1001)
)

.addPanel(
  row.new(title='Run Rate'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Aggregate',
      description='The per-second rate of all online GC runs.',
      query='sum by (worker) (rate(registry_gc_run_duration_seconds_count{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval]))',
      legendFormat='{{ worker }}',
      format='ops'
    ),
    basic.timeseries(
      title='Successful',
      description='The per-second rate of successful online GC runs.',

      query=|||
        sum by (worker) (
          rate(registry_gc_run_duration_seconds_count{error="false", noop="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ worker }}',
      format='ops'
    ),
    basic.timeseries(
      title='Failed',
      description='The per-second rate of failed online GC runs.',
      query=|||
        sum by (worker) (
          rate(registry_gc_run_duration_seconds_count{error="true", noop="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ worker }}',
      format='ops'
    ),
    basic.timeseries(
      title='Noop',
      description='The per-second rate of noop (no tasks available) online GC runs.',
      query=|||
        sum by (worker) (
          rate(registry_gc_run_duration_seconds_count{error="false", noop="true", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ worker }}',
      format='ops'
    ),
  ], cols=4, rowHeight=10, startRow=2001)
)

.addPanel(
  row.new(title='Run Latencies'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='P90 Aggregate',
      description='The estimated overal P90 latency of online GC runs.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (worker, le) (
            rate(registry_gc_run_duration_seconds_bucket{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ worker }}',
      format='s'
    ),
    basic.timeseries(
      title='P90 Successful',
      description='The estimated P90 latency of successful online GC runs.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (worker, le) (
            rate(registry_gc_run_duration_seconds_bucket{error="false", noop="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ worker }}',
      format='s'
    ),
    basic.timeseries(
      title='P90 Failed',
      description='The estimated P90 latency of failed online GC runs.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (worker, le) (
            rate(registry_gc_run_duration_seconds_bucket{error="true", noop="false", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ worker }}',
      format='s'
    ),
    basic.timeseries(
      title='P90 Noop',
      description='The estimated P90 latency of noop (false positive) online GC runs.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (worker, le) (
            rate(registry_gc_run_duration_seconds_bucket{error="false", noop="true", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ worker }}',
      format='s'
    ),
  ], cols=4, rowHeight=10, startRow=3001)
)

.addPanel(
  row.new(title='Delete Rate'),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Aggregate',
      description='The per-second rate of all online GC deletions.',
      query=|||
        sum by (backend) (
          rate(registry_gc_delete_duration_seconds_count{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ backend }}',
      format='ops'
    ),
    basic.timeseries(
      title='Blobs',
      description='The per-second rate of online GC blob deletions.',
      query=|||
        sum by (backend) (
          rate(registry_gc_delete_duration_seconds_count{artifact="blob", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ backend }}',
      format='ops'
    ),
    basic.timeseries(
      title='Manifests',
      description='The per-second rate of online GC manifest deletions.',
      query=|||
        sum by (backend) (
          rate(registry_gc_delete_duration_seconds_count{artifact="manifest", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
        )
      |||,
      legendFormat='{{ backend }}',
      format='ops'
    ),
  ], cols=3, rowHeight=10, startRow=4001)
)

.addPanel(
  row.new(title='Delete Latencies'),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='P90 Aggregate',
      description='The estimated overal P90 latency of online GC deletions.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (le) (
            rate(registry_gc_delete_duration_seconds_bucket{environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      format='s',
      legend_show=false
    ),
    basic.timeseries(
      title='P90 Blobs',
      description='The estimated P90 latency of online GC blob deletions.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (backend, le) (
            rate(registry_gc_delete_duration_seconds_bucket{artifact="blob", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ backend }}',
      format='s'
    ),
    basic.timeseries(
      title='P90 Manifests',
      description='The estimated P90 latency of online GC manifest deletions.',
      query=|||
        histogram_quantile(
          0.900000,
          sum by (backend, le) (
            rate(registry_gc_delete_duration_seconds_bucket{artifact="manifest", environment="$environment", stage="$stage", cluster=~"$cluster"}[$__interval])
          )
        )
      |||,
      legendFormat='{{ backend }}',
      format='s'
    ),
  ], cols=3, rowHeight=10, startRow=5001)
)

.addPanel(
  row.new(title='Events'),
  gridPos={
    x: 0,
    y: 6000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Queueing Rate',
      description='The per-second rate of online GC tasks queued, broken by triggering event.',
      query=|||
        sum by (event) (
          rate(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster", event!=""}[$__interval])
        )
      |||,
      legendFormat='{{ event }}',
      format='ops'
    ),
    basic.timeseries(
      title='Deletion Rate',
      description='The per-second rate of online GC tasks that result in a deletion, broken down by triggering event.',
      query=|||
        sum by (event) (
          rate(registry_gc_runs_total{environment="$environment", stage="$stage", cluster=~"$cluster", event!="", noop="false", dangling="true"}[$__interval])
        )
      |||,
      legendFormat='{{ event }}',
      format='ops'
    ),
  ], cols=2, rowHeight=12, startRow=6001)
)
