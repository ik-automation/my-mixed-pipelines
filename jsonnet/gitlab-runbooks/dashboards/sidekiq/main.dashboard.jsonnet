local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local sidekiq = import 'sidekiq.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

local shardDetailDataLink = {
  url: '/d/sidekiq-shard-detail?${__url_time_range}&${__all_variables}&var-shard=${__field.label.shard}&var-shard=${__field.label.shard}',
  title: 'Shard Detail: ${__field.label.shard}',
};

serviceDashboard.overview('sidekiq')
.addPanel(
  row.new(title='Sidekiq Queues'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.queueLengthTimeseries(
      title='Sidekiq Aggregated Queue Length',
      description='The total number of jobs in the system queued up to be executed. Lower is better.',
      query=|||
        sum(sidekiq_queue_size{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0))
      |||,
      legendFormat='Total Jobs',
      format='short',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='Queue Length',
    ),
    basic.queueLengthTimeseries(
      title='Sidekiq Queue Lengths per Queue',
      description='The number of jobs queued up to be executed. Lower is better',
      query=|||
        max_over_time(sidekiq_queue_size{environment="$environment"}[$__interval]) and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='{{ name }}',
      format='short',
      interval='1m',
      linewidth=1,
      intervalFactor=3,
      yAxisLabel='Queue Length',
    ),
    basic.queueLengthTimeseries(
      title='Sidekiq Queue Lengths per Worker',
      description='The number of jobs queued up to be executed. Lower is better',
      query=|||
        max_over_time(sidekiq_enqueued_jobs{environment="$environment"}[$__interval]) and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='{{ name }}',
      format='short',
      interval='1m',
      linewidth=1,
      intervalFactor=3,
      yAxisLabel='Queue Length',
    ),
    basic.latencyTimeseries(
      title='Sidekiq Queuing Latency per Queue',
      description='How long the oldest job has been waiting in the queue to execute. Lower is better',
      query=|||
        avg_over_time(sidekiq_queue_latency_seconds{environment="$environment"}[$__interval]) and on (fqdn) (redis_connected_slaves != 0)
        or
        avg_over_time(sidekiq_queue_latency{environment="$environment"}[$__interval]) and on (fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='{{ name }}',
      format='s',
      yAxisLabel='Duration',
      interval='1m',
      intervalFactor=3,
      legend_show=true,
      linewidth=1,
      min=0,
    ),
  ], cols=2, rowHeight=10, startRow=1001),
)
.addPanel(
  row.new(title='Sidekiq Queues (Global Search)', collapse=true)
  .addPanels(
    layout.grid([
      basic.multiTimeseries(
        title='Global search incremental indexing queue length',
        description='The number of records waiting to be synced to Elasticsearch for Global Search. These are picked up in batches every minute. Lower is better but the batching every minute means it will not usually stay at 0. Steady growth over a sustained period of time indicates that ElasticIndexBulkCronWorker is not keeping up.',
        queries=[
          {
            query: |||
              quantile(0.10, global_search_bulk_cron_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p10',
          },
          {
            query: |||
              quantile(0.50, global_search_bulk_cron_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p50',
          },
          {
            query: |||
              quantile(0.90, global_search_bulk_cron_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p90',
          },
        ],
        format='short',
        interval='1m',
        linewidth=1,
        intervalFactor=3,
        yAxisLabel='Queue Length',
      ),
      basic.multiTimeseries(
        title='Global search initial indexing queue length',
        description='The number of records waiting to be synced to Elasticsearch for Global Search during initial project backfill. These jobs are created when projects are imported or when Elasticsearch is enabled for a group in order to backfill all project data to the index. These are picked up in batches every minute. Lower is better but the batching every minute means it will not usually stay at 0. Sudden spikes are expected if a large group is enabled for Elasticsearch but sustained steady growth over a long period of time may indicate that ElasticIndexInitialBulkCronWorker is not keeping up.',
        queries=[
          {
            query: |||
              quantile(0.10, global_search_bulk_cron_initial_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p10',
          },
          {
            query: |||
              quantile(0.50, global_search_bulk_cron_initial_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p50',
          },
          {
            query: |||
              quantile(0.90, global_search_bulk_cron_initial_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p90',
          },
        ],
        format='short',
        interval='1m',
        linewidth=1,
        intervalFactor=3,
        yAxisLabel='Queue Length',
      ),
      basic.multiTimeseries(
        title='Global search awaiting indexing queue length',
        description='The number of records waiting to be synced to Elasticsearch for Global Search while indexing is paused.',
        queries=[
          {
            query: |||
              quantile(0.10, global_search_awaiting_indexing_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p10',
          },
          {
            query: |||
              quantile(0.50, global_search_awaiting_indexing_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p50',
          },
          {
            query: |||
              quantile(0.90, global_search_awaiting_indexing_queue_size{environment="$environment"})
            |||,
            legendFormat: 'p90',
          },
        ],
        format='short',
        interval='1m',
        linewidth=1,
        intervalFactor=3,
        yAxisLabel='Queue Length',
      ),
    ], cols=2, rowHeight=10, startRow=1501),
  ),
  gridPos={
    x: 0,
    y: 1500,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Sidekiq Future Sets'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.queueLengthTimeseries(
      title='Sidekiq Scheduled Set Delay',
      description='How late is scheduled job that is next to execute. Lower is better; up to 20 seconds is normal',
      query=|||
        sidekiq_schedule_set_processing_delay_seconds{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='Delay',
      format='s',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='Seconds',
    ),
    basic.queueLengthTimeseries(
      title='Sidekiq Scheduled Set Backlog',
      description='How many scheduled jobs are overdue. Lower is better; periodic processing means some backlog is normal',
      query=|||
        sidekiq_schedule_set_backlog_count{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='Backlog',
      format='short',
      interval='1m',
      linewidth=1,
      intervalFactor=3,
      yAxisLabel='Count',
    ),
    basic.queueLengthTimeseries(
      title='Sidekiq Retry Set Delay',
      description='How late is retry job that is next to execute. Lower is better; up to 20 seconds is normal',
      query=|||
        sidekiq_retry_set_processing_delay_seconds{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='Delay',
      format='s',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='Seconds',
    ),
    basic.queueLengthTimeseries(
      title='Sidekiq Retry Set Backlog',
      description='How many retry jobs are overdue. Lower is better; periodic processing means some backlog is normal',
      query=|||
        sidekiq_retry_set_backlog_count{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0)
      |||,
      legendFormat='Backlog',
      format='short',
      interval='1m',
      linewidth=1,
      intervalFactor=3,
      yAxisLabel='Count',
    ),
  ], cols=2, rowHeight=10, startRow=2001),
)
.addPanel(
  row.new(title='Sidekiq Execution'),
  gridPos={
    x: 0,
    y: 2500,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Sidekiq Total Execution Time',
      description='The sum of job execution times',
      query=|||
        sum(rate(sidekiq_jobs_completion_seconds_sum{environment="$environment"}[$__interval]))
      |||,
      legendFormat='Total',
      interval='1m',
      format='s',
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Job time completed per second',
    ),
    basic.timeseries(
      title='Sidekiq Total Execution Time Per Shard',
      description='The sum of job execution times',
      query=|||
        sum(rate(sidekiq_jobs_completion_seconds_sum{environment="$environment"}[$__interval])) by (shard)
      |||,
      legendFormat='{{ shard }}',
      interval='1m',
      format='s',
      linewidth=1,
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Job time completed per second',
    )
    .addDataLink(shardDetailDataLink),
    basic.timeseries(
      title='Sidekiq Aggregated Throughput',
      description='The total number of jobs being completed',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment"})
      |||,
      legendFormat='Total',
      interval='1m',
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    ),
    basic.timeseries(
      title='Sidekiq Throughput per Shard',
      description='The total number of jobs being completed per shard',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment"}) by (shard)
      |||,
      legendFormat='{{ shard }}',
      interval='1m',
      linewidth=1,
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    )
    .addDataLink(shardDetailDataLink),
    basic.timeseries(
      title='Sidekiq Throughput per Job',
      description='The total number of jobs being completed per shard',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment"}) by (queue)
      |||,
      legendFormat='{{ queue }}',
      interval='1m',
      intervalFactor=1,
      linewidth=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    ),
    basic.timeseries(
      title='Sidekiq Aggregated Inflight Operations',
      description='The total number of jobs being executed at a single moment',
      query=|||
        sum(sidekiq_running_jobs{environment="$environment"})
      |||,
      legendFormat='Total',
      interval='1m',
      intervalFactor=1,
      legend_show=true,
    ),
    basic.timeseries(
      title='Sidekiq Inflight Operations by Shard',
      description='The total number of jobs being executed at a single moment, for each queue',
      query=|||
        sum(sidekiq_running_jobs{environment="$environment"}) by (shard)
      |||,
      legendFormat='{{ shard }}',
      interval='1m',
      intervalFactor=1,
      legend_show=true,
      linewidth=1,
    )
    .addDataLink(shardDetailDataLink),
    basic.latencyTimeseries(
      title='Sidekiq Estimated Median Job Latency per shard',
      description='The median duration, once a job starts executing, that it runs for, by shard. Lower is better.',
      query=|||
        histogram_quantile(0.50,
          sum by (shard, le) (
            rate(sidekiq_jobs_completion_seconds_bucket{
              environment="$environment",
            }[$__interval])
          )
        )
      |||,
      legendFormat='{{ shard }}',
      format='s',
      yAxisLabel='Duration',
      interval='1m',
      intervalFactor=3,
      legend_show=true,
      logBase=10,
      linewidth=1,
      min=0.01,
    )
    .addDataLink(shardDetailDataLink),
    basic.latencyTimeseries(
      title='Sidekiq Estimated p95 Job Latency per shard',
      description='The 95th percentile duration, once a job starts executing, that it runs for, by shard. Lower is better.',
      query=|||
        histogram_quantile(0.95,
          sum by (shard, le) (
            rate(sidekiq_jobs_completion_seconds_bucket{
              environment="$environment",
            }[$__interval])
          )
        )
      |||,
      legendFormat='{{ shard }}',
      format='s',
      yAxisLabel='Duration',
      interval='2m',
      intervalFactor=5,
      legend_show=true,
      logBase=10,
      linewidth=1,
      min=0.01,
    )
    .addDataLink(shardDetailDataLink),
  ], cols=2, rowHeight=10, startRow=2501),
)
.addPanel(
  row.new(title='Shard Workloads'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(sidekiq.shardWorkloads('type="sidekiq", environment="$environment", stage="$stage"', startRow=3001, datalink=shardDetailDataLink))
.addPanel(
  row.new(title='Rails Metrics', collapse=true)
  .addPanels(railsCommon.railsPanels(serviceType='sidekiq', serviceStage='$stage', startRow=1)),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  }
)
.overviewTrailer()
