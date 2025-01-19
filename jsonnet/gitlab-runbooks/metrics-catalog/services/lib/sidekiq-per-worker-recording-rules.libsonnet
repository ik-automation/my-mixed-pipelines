local sidekiqHelpers = import './sidekiq-helpers.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local strings = import 'utils/strings.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;


// This is used to calculate the queue apdex across all queues
local combinedQueueApdex = combined([
  histogramApdex(
    histogram='sidekiq_jobs_queue_duration_seconds_bucket',
    selector={ urgency: 'high' },
    satisfiedThreshold=sidekiqHelpers.slos.urgent.queueingDurationSeconds,
  ),
  histogramApdex(
    histogram='sidekiq_jobs_queue_duration_seconds_bucket',
    selector={ urgency: 'low' },
    satisfiedThreshold=sidekiqHelpers.slos.lowUrgency.queueingDurationSeconds,
  ),
]);

local combinedExecutionApdex = combined([
  histogramApdex(
    histogram='sidekiq_jobs_completion_seconds_bucket',
    selector={ urgency: 'high' },
    satisfiedThreshold=sidekiqHelpers.slos.urgent.executionDurationSeconds,
  ),
  histogramApdex(
    histogram='sidekiq_jobs_completion_seconds_bucket',
    selector={ urgency: 'low' },
    satisfiedThreshold=sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,
  ),
  histogramApdex(
    histogram='sidekiq_jobs_completion_seconds_bucket',
    selector={ urgency: 'throttled' },
    satisfiedThreshold=sidekiqHelpers.slos.throttled.executionDurationSeconds,
  ),
]);

local queueRate = rateMetric(
  counter='sidekiq_enqueued_jobs_total',
  selector={},
);

local requestRate = rateMetric(
  counter='sidekiq_jobs_completion_seconds_bucket',
  selector={ le: '+Inf' },
);

local errorRate = rateMetric(
  counter='sidekiq_jobs_failed_total',
  selector={},
);

local executionRulesForBurnRate(aggregationSet, burnRate, staticLabels={}) =
  local aggregationLabelsWithoutStaticLabels = std.filter(
    function(label)
      !std.objectHas(staticLabels, label),
    aggregationSet.labels
  );

  local conditionalAppend(record, expr) =
    if record == null then []
    else
      [{
        record: record,
        [if staticLabels != {} then 'labels']: staticLabels,
        expr: expr,
      }];

  // Key metric: Execution apdex success (rate)
  conditionalAppend(
    record=aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=false),
    expr=combinedExecutionApdex.apdexSuccessRateQuery(aggregationLabelsWithoutStaticLabels, {}, burnRate)
  )
  +
  // Key metric: Execution apdex (weight score)
  conditionalAppend(
    record=aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=false),
    expr=combinedExecutionApdex.apdexWeightQuery(aggregationLabelsWithoutStaticLabels, {}, burnRate),
  )
  +
  // Key metric: QPS
  conditionalAppend(
    record=aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=false),
    expr=requestRate.aggregatedRateQuery(aggregationLabelsWithoutStaticLabels, {}, burnRate)
  )
  +
  // Key metric: Errors per Second
  conditionalAppend(
    record=aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=false),
    expr=|||
      %(errorRate)s
      or
      (
        0 * group by (%(aggregationLabels)s) (
          %(executionRate)s{%(staticLabels)s}
        )
      )
    ||| % {
      errorRate: strings.chomp(errorRate.aggregatedRateQuery(aggregationLabelsWithoutStaticLabels, {}, burnRate)),
      aggregationLabels: aggregations.serialize(aggregationLabelsWithoutStaticLabels),
      executionRate: aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true),
      staticLabels: selectors.serializeHash(staticLabels),
    }
  );

local queueRulesForBurnRate(aggregationSet, burnRate, staticLabels={}) =
  local conditionalAppend(record, expr) =
    if record == null then []
    else
      [{
        record: record,
        expr: expr,
      }];

  // Key metric: Queueing apdex success (rate)
  conditionalAppend(
    record=aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=false),
    expr=combinedQueueApdex.apdexSuccessRateQuery(aggregationSet.labels, staticLabels, burnRate)
  )
  +
  // Key metric: Queueing apdex (weight score)
  conditionalAppend(
    record=aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=false),
    expr=combinedQueueApdex.apdexWeightQuery(aggregationSet.labels, staticLabels, burnRate)
  )
  +
  // Key metric: Queueing operations/second
  conditionalAppend(
    record=aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=false),
    expr=queueRate.aggregatedRateQuery(aggregationSet.labels, staticLabels, burnRate)
  );

{
  perWorkerRecordingRulesForAggregationSet(aggregationSet, staticLabels={})::
    std.flatMap(function(burnRate) executionRulesForBurnRate(aggregationSet, burnRate, staticLabels), aggregationSet.getBurnRates()),

  // Record queue apdex, execution apdex, error rates, QPS metrics
  // for each worker, similar to how we record these for each
  // service
  perWorkerRecordingRules(rangeInterval)::
    queueRulesForBurnRate(aggregationSets.sidekiqWorkerQueueSourceSLIs, rangeInterval)
    +
    executionRulesForBurnRate(aggregationSets.sidekiqWorkerExecutionSourceSLIs, rangeInterval),
}
