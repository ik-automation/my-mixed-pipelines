local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local template = grafana.template;
local saturationDetail = import 'gitlab-dashboards/saturation_detail.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local link = grafana.link;
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';

local selectors = import 'promql/selectors.libsonnet';

local optimalUtilization = 0.33;
local optimalMargin = 0.10;

local selectorHash = { type: 'sidekiq', environment: '$environment', stage: '$stage', shard: { re: '$shard' } };
local selector = selectors.serializeHash(selectorHash);

local workerDetailDataLink = {
  url: '/d/sidekiq-worker-detail?${__url_time_range}&${__all_variables}&var-worker=${__field.label.worker}',
  title: 'Worker Detail: ${__field.labels.worker}',
};

local queueTimeLatencyTimeseries(title, aggregator) =
  basic.latencyTimeseries(
    title=title,
    description='Estimated queue time, between when the job is enqueued and executed. Lower is better.',
    query=|||
      histogram_quantile(0.95, sum(sli_aggregations:sidekiq_jobs_queue_duration_seconds_bucket_rate5m{environment="$environment", shard=~"$shard"}) by (le, %s))
    ||| % [aggregator],
    legendFormat='{{ %s }}' % [aggregator],
    format='s',
    yAxisLabel='Queue Duration',
    interval='1m',
    intervalFactor=3,
    legend_show=true,
    logBase=10,
    linewidth=1,
    min=0.01,
  );

local inflightJobsTimeseries(title, aggregator) =
  basic.timeseries(
    title=title,
    description='The total number of jobs being executed at a single moment for the shard',
    query=|||
      sum(sidekiq_running_jobs{environment="$environment", shard=~"$shard"}) by (%s)
    ||| % [aggregator],
    legendFormat='{{ %s }}' % [aggregator],
    interval='1m',
    intervalFactor=1,
    legend_show=true,
    linewidth=1,
  );

basic.dashboard(
  'Shard Detail',
  tags=['type:sidekiq', 'detail'],
)
.addTemplate(templates.stage)
.addTemplate(template.new(
  'shard',
  '$PROMETHEUS_DS',
  'label_values(up{environment="$environment", type="sidekiq"}, shard)',
  current='catchall',
  refresh='load',
  sort=1,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanels(
  layout.rowGrid('Queue Lengths - number of jobs queued', [
    basic.queueLengthTimeseries(
      title='Queue Lengths',
      description='The number of unstarted jobs in queues serviced by this shard',
      query=|||
        sum by (queue) (
          (
            label_replace(
              sidekiq_queue_size{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0),
              "queue", "$0", "name", ".*"
            )
          )
          and on (queue)
          (
            max by (queue) (
              sli_aggregations:sidekiq_jobs_queue_duration_seconds_bucket_rate1m{environment="$environment", shard=~"$shard"} > 0
            )
          )
        )
      |||,
      legendFormat='{{ queue }}',
      format='short',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='Jobs',
    )
    .addDataLink(workerDetailDataLink),
    basic.queueLengthTimeseries(
      title='Aggregate queue length',
      description='The sum total number of unstarted jobs in all queues serviced by this shard',
      query=|||
        sum(
          (
            label_replace(
              sidekiq_queue_size{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0),
              "queue", "$0", "name", ".*"
            )
          )
          and on (queue)
          (
            max by (queue) (
              sli_aggregations:sidekiq_jobs_queue_duration_seconds_bucket_rate1m{environment="$environment", shard=~"$shard"} > 0
            )
          )
        )
      |||,
      legendFormat='Aggregated queue length',
      format='short',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='Jobs',
    ),
  ], startRow=101)
  +
  layout.rowGrid('Queue Time - time spend queueing', [
    queueTimeLatencyTimeseries(
      title='Sidekiq Estimated p95 Job Queue Time for $shard shard',
      aggregator='shard'
    ),
    queueTimeLatencyTimeseries(
      title='Sidekiq Estimated p95 Job Queue Time per Queue, $shard shard',
      aggregator='queue'
    ),
    queueTimeLatencyTimeseries(
      title='Sidekiq Estimated p95 Job Queue Time per Worker, $shard shard',
      aggregator='worker'
    )
    .addDataLink(workerDetailDataLink),
  ], startRow=201)
  +
  layout.rowGrid('Inflight Jobs - jobs currently running', [
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs for $shard shard',
      aggregator='shard'
    ),
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs per Queue, $shard shard',
      aggregator='queue'
    ),
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs per Worker, $shard shard',
      aggregator='worker'
    )
    .addDataLink(workerDetailDataLink),
  ], startRow=301)
  +
  layout.rowGrid('Individual Execution Time - time taken for individual jobs to complete', [
    basic.multiTimeseries(
      title='Sidekiq Estimated Median Job Latency for $shard shard',
      description='The median duration, once a job starts executing, that it runs for, by shard. Lower is better.',
      queries=[
        {
          query: |||
            histogram_quantile(0.50,
              sum by (shard, le) (
                sli_aggregations:sidekiq_jobs_completion_seconds_bucket_rate5m{
                  environment="$environment",
                  shard=~"$shard"
                }
              )
            )
          |||,
          legendFormat: '{{ shard }} p50',
        },
        {
          query: |||
            histogram_quantile(0.95,
              sum by (shard, le) (
                sli_aggregations:sidekiq_jobs_completion_seconds_bucket_rate5m{
                  environment="$environment",
                  shard=~"$shard"
                }
              )
            )
          |||,
          legendFormat: '{{ shard }} p95',
        },
      ],
      format='s',
      yAxisLabel='Duration',
      interval='1m',
      intervalFactor=3,
      legend_show=true,
      linewidth=1,
    ),
    basic.latencyTimeseries(
      title='Sidekiq Estimated p95 Job Latency per Queue, for $shard shard',
      description='The 95th percentile duration, once a job starts executing, that it runs for, by queue. Lower is better.',
      query=|||
        histogram_quantile(0.95,
          sum by (queue, le) (
            sli_aggregations:sidekiq_jobs_completion_seconds_bucket_rate5m{
              environment="$environment",
              shard=~"$shard"
            }
          )
        )
      |||,
      legendFormat='p95 {{ queue }}',
      format='s',
      yAxisLabel='Duration',
      interval='2m',
      intervalFactor=5,
      legend_show=true,
      logBase=10,
      linewidth=1,
    ),
    basic.latencyTimeseries(
      title='Sidekiq Estimated p95 Job Latency per Worker, for $shard shard',
      description='The 95th percentile duration, once a job starts executing, that it runs for, by worker. Lower is better.',
      query=|||
        histogram_quantile(0.95,
          sum by (worker, le) (
            sli_aggregations:sidekiq_jobs_completion_seconds_bucket_rate5m{
              environment="$environment",
              shard=~"$shard"
            }
          )
        )
      |||,
      legendFormat='p95 {{ worker }}',
      format='s',
      yAxisLabel='Duration',
      interval='2m',
      intervalFactor=5,
      legend_show=true,
      logBase=10,
      linewidth=1,
    ),
  ], startRow=401)
  +
  layout.rowGrid('Total Execution Time - total time consumed processing jobs', [
    basic.timeseries(
      title='Sidekiq Total Execution Time for $shard Shard',
      description='The sum of job execution times',
      query=|||
        sum(sidekiq_jobs_execution_time:1m{environment="$environment", shard=~"$shard"}) by (shard)
      |||,
      legendFormat='{{ shard }}',
      interval='1m',
      format='s',
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Job time completed per second',
    ),
  ], startRow=501)
  +
  layout.rowGrid('Throughput - rate at which jobs complete', [
    basic.timeseries(
      title='Sidekiq Aggregated Throughput for $shard Shard',
      description='The total number of jobs being completed',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment", shard=~"$shard"}) by (shard)
      |||,
      legendFormat='{{ shard }}',
      interval='1m',
      intervalFactor=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    ),
    basic.timeseries(
      title='Sidekiq Throughput per Queue for $shard Shard',
      description='The total number of jobs being completed per queue for shard',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment", shard=~"$shard"}) by (queue)
      |||,
      legendFormat='{{ queue }}',
      interval='1m',
      intervalFactor=1,
      linewidth=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    ),
    basic.timeseries(
      title='Sidekiq Throughput per Worker for $shard Shard',
      description='The total number of jobs being completed per worker for shard',
      query=|||
        sum(queue:sidekiq_jobs_completion:rate1m{environment="$environment", shard=~"$shard"}) by (worker)
      |||,
      legendFormat='{{ worker }}',
      interval='1m',
      intervalFactor=1,
      linewidth=1,
      legend_show=true,
      yAxisLabel='Jobs Completed per Second',
    )
    .addDataLink(workerDetailDataLink),
  ], startRow=601)
  +
  layout.rowGrid('Utilization - saturation of workers in this fleet', [
    basic.percentageTimeseries(
      'Shard Utilization',
      description='How heavily utilized is this shard? Ideally this should be around 33% plus minus 10%. If outside this range for long periods, consider scaling fleet appropriately.',
      query=|||
        sum by (shard, stage) (sidekiq_jobs_execution_time:1h{environment="$environment", shard=~"$shard"})
        /
        sum by (stage, shard)  (avg_over_time(sidekiq_concurrency{environment="$environment", shard=~"$shard"}[1h]))
      |||,
      legendFormat='{{ shard }} utilization (per hour)',
      yAxisLabel='Percent',
      interval='5m',
      intervalFactor=1,
      linewidth=2,
      max=1,
      thresholds=[
        thresholds.optimalLevel('gt', optimalUtilization - optimalMargin),
        thresholds.optimalLevel('lt', optimalUtilization + optimalMargin),
        thresholds.warningLevel('gt', optimalUtilization + optimalMargin),
      ]
    )
    .addTarget(
      promQuery.target(
        expr=|||
          sum by (shard, stage) (sidekiq_jobs_execution_time:10m{environment="$environment", shard=~"$shard"})
          /
          sum by (stage, shard)  (avg_over_time(sidekiq_concurrency{environment="$environment", shard=~"$shard"}[10m]))
        |||,
        legendFormat='{{ shard }} utilization (per 10m)'
      )
    )
    .addTarget(
      promQuery.target(
        expr=|||
          sum by (shard, stage) (sidekiq_jobs_execution_time:1m{environment="$environment", shard=~"$shard"})
          /
          sum by (stage, shard)  (avg_over_time(sidekiq_concurrency{environment="$environment", shard=~"$shard"}[1m]))
        |||,
        legendFormat='{{ shard }} utilization (instant)'
      )
    ),

  ], startRow=701)
)
.addPanel(
  row.new(title='Rails Metrics', collapse=true)
  .addPanels(railsCommon.railsPanels(serviceType='sidekiq', serviceStage='$stage', startRow=1)),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanel(nodeMetrics.nodeMetricsDetailRow(selector), gridPos={ x: 0, y: 4000 })
.addPanel(
  saturationDetail.saturationDetailPanels(selectorHash, components=[
    'cpu',
    'disk_space',
    'memory',
    'open_fds',
    'sidekiq_shard_workers',
    'single_node_cpu',
    'single_node_puma_workers',
  ]),
  gridPos={ x: 0, y: 5000, w: 24, h: 1 }
)
+ {
  links+:
    platformLinks.triage +
    platformLinks.services +
    [
      platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq'),
      link.dashboards(
        'ELK $shard shard logs',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticDiscoverSearchQueryURL(
          'sidekiq', [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ]
        ),
      ),
      link.dashboards(
        'ELK $shard shard ops/sec visualization',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticLineCountVizURL(
          'sidekiq', [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ]
        ),
      ),
      link.dashboards(
        'ELK $shard shard latency visualization',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticLinePercentileVizURL(
          'sidekiq',
          [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ],
          field='json.duration_s'
        ),
      ),
    ],
}
