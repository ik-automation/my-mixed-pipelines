local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local link = grafana.link;
local template = grafana.template;
local sidekiqHelpers = import 'services/lib/sidekiq-helpers.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local row = grafana.row;
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local issueSearch = import 'gitlab-dashboards/issue_search.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = {
  environment: '$environment',
  type: 'sidekiq',
  stage: '$stage',
  queue: { re: '$queue' },
};

local recordingRuleLatencyHistogramQuery(percentile, recordingRule, selector, aggregator) =
  |||
    histogram_quantile(%(percentile)g, sum by (%(aggregator)s, le) (
      %(recordingRule)s{%(selector)s}
    ))
  ||| % {
    percentile: percentile,
    aggregator: aggregator,
    selector: selectors.serializeHash(selector),
    recordingRule: recordingRule,
  };

local recordingRuleRateQuery(recordingRule, selector, aggregator) =
  |||
    sum by (%(aggregator)s) (
      %(recordingRule)s{%(selector)s}
    )
  ||| % {
    aggregator: aggregator,
    selector: selectors.serializeHash(selector),
    recordingRule: recordingRule,
  };

local queuelatencyTimeseries(title, aggregators, legendFormat) =
  basic.latencyTimeseries(
    title=title,
    query=recordingRuleLatencyHistogramQuery(0.95, 'sli_aggregations:sidekiq_jobs_queue_duration_seconds_bucket_rate5m', selector, aggregators),
    legendFormat=legendFormat,
  );


local latencyTimeseries(title, aggregators, legendFormat) =
  basic.latencyTimeseries(
    title=title,
    query=recordingRuleLatencyHistogramQuery(0.95, 'sli_aggregations:sidekiq_jobs_completion_seconds_bucket_rate5m', selector, aggregators),
    legendFormat=legendFormat,
  );

local enqueueCountTimeseries(title, aggregators, legendFormat) =
  basic.timeseries(
    title=title,
    query=recordingRuleRateQuery('gitlab_background_jobs:queue:ops:rate_5m', 'environment="$environment", queue=~"$queue"', aggregators),
    legendFormat=legendFormat,
  );

local rpsTimeseries(title, aggregators, legendFormat) =
  basic.timeseries(
    title=title,
    query=recordingRuleRateQuery('gitlab_background_jobs:execution:ops:rate_5m', 'environment="$environment", queue=~"$queue"', aggregators),
    legendFormat=legendFormat,
  );

local errorRateTimeseries(title, aggregators, legendFormat) =
  basic.timeseries(
    title=title,
    query=recordingRuleRateQuery('gitlab_background_jobs:execution:error:rate_5m', 'environment="$environment", queue=~"$queue"', aggregators),
    legendFormat=legendFormat,
  );

local elasticFilters = [matching.matchFilter('json.stage.keyword', '$stage')];
local elasticQueries = ['json.queue.keyword:${queue:lucene}'];

local elasticsearchLogSearchDataLink = {
  url: elasticsearchLinks.buildElasticDiscoverSearchQueryURL('sidekiq', elasticFilters, elasticQueries),
  title: 'ElasticSearch: Sidekiq logs',
  targetBlank: true,
};

basic.dashboard(
  'Queue Detail',
  tags=['type:sidekiq', 'detail'],
)
.addTemplate(templates.stage)
.addTemplate(template.new(
  'queue',
  '$PROMETHEUS_DS',
  'label_values(gitlab_background_jobs:queue:apdex:weight:score_1h{environment="$environment", type="sidekiq"}, queue)',
  current='post_receive',
  refresh='load',
  sort=1,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanels(
  layout.grid([
    basic.labelStat(
      query=|||
        label_replace(
          topk by (queue) (1, sum(rate(sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue"}[$__range])) by (queue, %(label)s)),
          "%(label)s", "%(default)s", "%(label)s", ""
        )
      ||| % {
        label: attribute.label,
        default: attribute.default,
      },
      title='Queue Attribute: ' + attribute.title,
      color=attribute.color,
      legendFormat='{{ %s }} ({{ queue }})' % [attribute.label],
      links=attribute.links
    )
    for attribute in [{
      label: 'urgency',
      title: 'Urgency',
      color: 'yellow',
      default: 'unknown',
      links: [],
    }, {
      label: 'feature_category',
      title: 'Feature Category',
      color: 'blue',
      default: 'unknown',
      links: [],
    }, {
      label: 'shard',
      title: 'Shard',
      color: 'orange',
      default: 'unknown',
      links: [{
        title: 'Sidekiq Shard Detail: ${__field.label.shard}',
        url: '/d/sidekiq-shard-detail/sidekiq-shard-detail?orgId=1&var-shard=${__field.label.shard}&var-environment=${environment}&var-stage=${stage}&${__url_time_range}',
      }],
    }, {
      label: 'external_dependencies',
      title: 'External Dependencies',
      color: 'green',
      default: 'none',
      links: [],
    }, {
      label: 'boundary',
      title: 'Resource Boundary',
      color: 'purple',
      default: 'none',
      links: [],
    }]
  ] + [
    basic.statPanel(
      'Max Queuing Duration SLO',
      'Max Queuing Duration SLO',
      'light-red',
      |||
        vector(NaN) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="throttled"}
        or
        vector(%(lowUrgencySLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="low"}
        or
        vector(%(urgentSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="high"}
      ||| % {
        lowUrgencySLO: sidekiqHelpers.slos.lowUrgency.queueingDurationSeconds,
        urgentSLO: sidekiqHelpers.slos.urgent.queueingDurationSeconds,
      },
      '{{ queue }}',
      unit='s',
    ),
    basic.statPanel(
      'Max Execution Duration SLO',
      'Max Execution Duration SLO',
      'red',
      |||
        vector(%(throttledSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="throttled"}
        or
        vector(%(lowUrgencySLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="low"}
        or
        vector(%(urgentSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", queue=~"$queue", urgency="high"}
      ||| % {
        throttledSLO: sidekiqHelpers.slos.throttled.executionDurationSeconds,
        lowUrgencySLO: sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,
        urgentSLO: sidekiqHelpers.slos.urgent.executionDurationSeconds,
      },
      '{{ queue }}',
      unit='s',
    ),
    basic.statPanel(
      'Time until backlog is cleared',
      'Backlog',
      'blue',
      |||
        ((sidekiq_queue_size{environment="$environment", name=~"$queue"} and on(fqdn) (redis_connected_slaves != 0)) > 10)
        /
        (-deriv(sidekiq_queue_size{environment="$environment", name=~"$queue"}[5m]) and on(fqdn) (redis_connected_slaves != 0) > 0)
      |||,
      '{{ name }}',
      unit='s',
    ),
  ], cols=8, rowHeight=4)
  +
  [row.new(title='🌡 Queue Key Metrics') { gridPos: { x: 0, y: 100, w: 24, h: 1 } }]
  +
  layout.grid([
    basic.apdexTimeseries(
      stableId='queue-apdex',
      title='Queue Apdex',
      description='Queue apdex monitors the percentage of jobs that are dequeued within their queue threshold. Higher is better. Different jobs have different thresholds.',
      query=|||
        sum by (queue) (
          (gitlab_background_jobs:queue:apdex:ratio_5m{environment="$environment", queue=~"$queue"} >= 0)
          *
          (gitlab_background_jobs:queue:apdex:weight:score_5m{environment="$environment", queue=~"$queue"} >= 0)
        )
        /
        sum by (queue) (
          (gitlab_background_jobs:queue:apdex:weight:score_5m{environment="$environment", queue=~"$queue"})
        )
      |||,
      yAxisLabel='% Jobs within Max Queuing Duration SLO',
      legendFormat='{{ queue }} queue apdex',
      legend_show=true,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('/.* queue apdex$/'))
    .addDataLink(elasticsearchLogSearchDataLink)
    .addDataLink({
      url: elasticsearchLinks.buildElasticLinePercentileVizURL('sidekiq', elasticFilters, elasticQueries, 'json.scheduling_latency_s'),
      title: 'ElasticSearch: queue latency visualization',
      targetBlank: true,
    }),
    basic.apdexTimeseries(
      stableId='execution-apdex',
      title='Execution Apdex',
      description='Execution apdex monitors the percentage of jobs that run within their execution (run-time) threshold. Higher is better. Different jobs have different thresholds.',
      query=|||
        sum by (queue) (
          (gitlab_background_jobs:execution:apdex:ratio_5m{environment="$environment", queue=~"$queue"} >= 0)
          *
          (gitlab_background_jobs:execution:apdex:weight:score_5m{environment="$environment", queue=~"$queue"} >= 0)
        )
        /
        sum by (queue) (
          (gitlab_background_jobs:execution:apdex:weight:score_5m{environment="$environment", queue=~"$queue"})
        )
      |||,
      yAxisLabel='% Jobs within Max Execution Duration SLO',
      legendFormat='{{ queue }} execution apdex',
      legend_show=true,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('/.* execution apdex$/'))
    .addDataLink(elasticsearchLogSearchDataLink)
    .addDataLink({
      url: elasticsearchLinks.buildElasticLinePercentileVizURL('sidekiq', elasticFilters, elasticQueries, 'json.duration_s'),
      title: 'ElasticSearch: execution latency visualization',
      targetBlank: true,
    }),

    basic.timeseries(
      stableId='request-rate',
      title='Execution Rate (RPS)',
      description='Jobs executed per second',
      query=|||
        sum by (queue) (gitlab_background_jobs:execution:ops:rate_5m{environment="$environment", queue=~"$queue"})
      |||,
      legendFormat='{{ queue }} rps',
      format='ops',
      yAxisLabel='Jobs per Second',
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('/.* rps$/'))
    .addDataLink(elasticsearchLogSearchDataLink)
    .addDataLink({
      url: elasticsearchLinks.buildElasticLineCountVizURL('sidekiq', elasticFilters, elasticQueries),
      title: 'ElasticSearch: RPS visualization',
      targetBlank: true,
    }),

    basic.percentageTimeseries(
      stableId='error-ratio',
      title='Error Ratio',
      description='Percentage of jobs that fail with an error. Lower is better.',
      query=|||
        sum by (queue) (
          (gitlab_background_jobs:execution:error:rate_5m{environment="$environment", queue=~"$queue"} >= 0)
        )
        /
        sum by (queue) (
          (gitlab_background_jobs:execution:ops:rate_5m{environment="$environment", queue=~"$queue"} >= 0)
        )
      |||,
      legendFormat='{{ queue }} error ratio',
      yAxisLabel='Error Percentage',
      legend_show=true,
      decimals=2,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('/.* error ratio$/'))
    .addDataLink(elasticsearchLogSearchDataLink)
    .addDataLink({
      url: elasticsearchLinks.buildElasticLineCountVizURL(
        'sidekiq',
        elasticFilters + [matching.matchFilter('json.job_status', 'fail')],
        elasticQueries
      ),
      title: 'ElasticSearch: errors visualization',
      targetBlank: true,
    }),
  ], cols=4, rowHeight=8, startRow=101)
  +
  layout.rowGrid('Enqueuing (rate of jobs enqueuing)', [
    enqueueCountTimeseries('Jobs Enqueued', aggregators='queue', legendFormat='{{ queue }}'),
    enqueueCountTimeseries('Jobs Enqueued per Service', aggregators='type, queue', legendFormat='{{ queue }} - {{ type }}'),
    basic.timeseries(
      stableId='enqueued-by-scheduling-type',
      title='Jobs Enqueued by Schedule',
      description='Enqueue events separated by immediate (destined for execution) vs delayed (destined for ScheduledSet) scheduling.',
      query=|||
        sum by (queue, scheduling) (
          rate(sidekiq_enqueued_jobs_total{environment="$environment", stage="$stage", queue=~"$queue"}[$__interval])
          )
      |||,
      legendFormat='{{ queue }} - {{ scheduling }}',
    ),
    basic.queueLengthTimeseries(
      stableId='queue-length',
      title='Queue length',
      description='The number of unstarted jobs in a queue',
      query=|||
        max by (name) (max_over_time(sidekiq_queue_size{environment="$environment", name=~"$queue"}[$__interval]) and on(fqdn) (redis_connected_slaves != 0))
      |||,
      legendFormat='{{ name }}',
      format='short',
      interval='1m',
      intervalFactor=3,
      yAxisLabel='',
    ),
  ], startRow=201)
  +
  layout.rowGrid('Queue Latency (the amount of time spent queueing)', [
    queuelatencyTimeseries('Queue Time', aggregators='queue', legendFormat='p95 {{ queue }}'),
  ], startRow=301)
  +
  layout.rowGrid('Execution Latency (the amount of time the job takes to execute after dequeue)', [
    latencyTimeseries('Execution Time', aggregators='queue', legendFormat='p95 {{ queue }}'),
  ], startRow=401)
  +
  layout.rowGrid('Execution RPS (the rate at which jobs are completed after dequeue)', [
    rpsTimeseries('RPS', aggregators='queue', legendFormat='{{ queue }}'),
  ], startRow=501)
  +
  layout.rowGrid('Error Rate (the rate at which jobs fail)', [
    errorRateTimeseries('Errors', aggregators='queue', legendFormat='{{ queue }}'),
    basic.timeseries(
      title='Dead Jobs',
      query=|||
        sum by (queue) (
          increase(sidekiq_jobs_dead_total{%(selector)s}[5m])
        )
      ||| % {
        selector: selectors.serializeHash(selector),
      },
      legendFormat='{{ queue }}',
    ),
  ], startRow=601)
  +
  [
    row.new(title='Resource Usage') { gridPos: { x: 0, y: 701, w: 24, h: 1 } },
  ] +
  layout.grid(
    [
      basic.multiQuantileTimeseries('CPU Time', selector, '{{ queue }}', bucketMetric='sidekiq_jobs_cpu_seconds_bucket', aggregators='queue'),
      basic.multiQuantileTimeseries('Gitaly Time', selector, '{{ queue }}', bucketMetric='sidekiq_jobs_gitaly_seconds_bucket', aggregators='queue'),
      basic.multiQuantileTimeseries('Database Time', selector, '{{ queue }}', bucketMetric='sidekiq_jobs_db_seconds_bucket', aggregators='queue'),
    ], cols=3, startRow=702
  )
  +
  layout.grid(
    [
      basic.multiQuantileTimeseries('Redis Time', selector, '{{ queue }}', bucketMetric='sidekiq_redis_requests_duration_seconds_bucket', aggregators='queue'),
      basic.multiQuantileTimeseries('Elasticsearch Time', selector, '{{ queue }}', bucketMetric='sidekiq_elasticsearch_requests_duration_seconds_bucket', aggregators='queue'),
    ], cols=3, startRow=703
  )
  +
  layout.rowGrid('SQL', [
    basic.multiTimeseries(
      stableId='total-sql-queries-rate',
      title='Total SQL Queries Rate',
      format='ops',
      queries=[
        {
          query: |||
            sum by (endpoint_id) (
              rate(
                gitlab_transaction_db_count_total{%(selector)s}[$__interval]
              )
            )
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ endpoint_id }} - total',
        },
        {
          query: |||
            sum by (endpoint_id) (
              rate(
                gitlab_transaction_db_primary_count_total{%(selector)s}[$__interval]
              )
            )
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ endpoint_id }} - primary',
        },
        {
          query: |||
            sum by (endpoint_id) (
              rate(
                gitlab_transaction_db_replica_count_total{%(selector)s}[$__interval]
              )
            )
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ endpoint_id }} - replica',
        },
      ]
    ),
    basic.timeseries(
      stableId='sql-transaction',
      title='SQL Transactions Rate',
      query=|||
        sum by (endpoint_id) (
          rate(gitlab_database_transaction_seconds_count{%(selector)s}[$__interval])
        )
      ||| % { selector: selectors.serializeHash(selector) },
      legendFormat='{{ endpoint_id }}',
    ),
    basic.multiTimeseries(
      stableId='sql-transaction-holding-duration',
      title='SQL Transaction Holding Duration',
      format='s',
      queries=[
        {
          query: |||
            sum(rate(gitlab_database_transaction_seconds_sum{%(selector)s}[$__interval])) by (endpoint_id)
            /
            sum(rate(gitlab_database_transaction_seconds_count{%(selector)s}[$__interval])) by (endpoint_id)
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ endpoint_id }} - p50',
        },
        {
          query: |||
            histogram_quantile(0.95, sum(rate(gitlab_database_transaction_seconds_bucket{%(selector)s}[$__interval])) by (endpoint_id, le))
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ endpoint_id }} - p95',
        },
      ],
    ),
  ], startRow=901)
)
.trailer()
+ {
  links+:
    platformLinks.triage +
    platformLinks.services +
    [
      platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq'),
      link.dashboards(
        'Find issues for $queue',
        '',
        type='link',
        targetBlank=true,
        url=issueSearch.buildInfraIssueSearch(labels=['Service::Sidekiq'], search='$queue')
      ),
    ],
}
