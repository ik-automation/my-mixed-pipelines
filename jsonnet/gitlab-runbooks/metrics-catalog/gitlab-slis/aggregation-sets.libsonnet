local sliDefinition = import 'gitlab-slis/sli-definition.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';

local defaultLabels = ['environment', 'tier', 'type', 'stage'];
local globalLabels = ['env'];
local supportedBurnRates = ['5m', '1h'];

local resolvedRecording(metric, labels, burnRate) =
  assert recordingRuleRegistry.resolveRecordingRuleFor(
    metricName=metric, aggregationLabels=labels, rangeInterval=burnRate
  ) != null : 'No previous recording found for %s and burn rate %s' % [metric, burnRate];
  recordingRuleRegistry.recordingRuleNameFor(metric, burnRate);

local recordedBurnRatesForSLI(sli) =
  std.foldl(
    function(memo, burnRate)
      local apdex =
        if sli.hasApdex() then
          {
            apdexSuccessRate: resolvedRecording(sli.apdexSuccessCounterName, sli.significantLabels, burnRate),
            apdexWeight: resolvedRecording(sli.apdexTotalCounterName, sli.significantLabels, burnRate),
          }
        else {};

      local errorRate =
        if sli.hasErrorRate() then
          {
            errorRate: resolvedRecording(sli.errorCounterName, sli.significantLabels, burnRate),
            opsRate: resolvedRecording(sli.errorTotalCounterName, sli.significantLabels, burnRate),
          }
        else {};

      memo { [burnRate]: apdex + errorRate },
    supportedBurnRates,
    {}
  );

local aggregationFormats(sli) =
  local format = { sliName: sli.name, burnRate: '%s' };

  local apdex = if sli.hasApdex() then
    {
      apdexSuccessRate: 'application_sli_aggregation:%(sliName)s:apdex:success:rate_%(burnRate)s' % format,
      apdexWeight: 'application_sli_aggregation:%(sliName)s:apdex:weight:score_%(burnRate)s' % format,
    }
  else
    {};

  apdex + if sli.hasErrorRate() then
    {
      opsRate: 'application_sli_aggregation:%(sliName)s:ops:rate_%(burnRate)s' % format,
      errorRate: 'application_sli_aggregation:%(sliName)s:error:rate_%(burnRate)s' % format,
    }
  else
    {};

local sourceAggregationSet(sli) =
  aggregationSet.AggregationSet(
    {
      id: 'source_application_sli_%s' % sli.name,
      name: 'Application Defined SLI Source metrics: %s' % sli.name,
      labels: defaultLabels + sli.significantLabels,
      intermediateSource: true,
      selector: { monitor: { ne: 'global' } },
      supportedBurnRates: supportedBurnRates,
    }
    +
    if sli.inRecordingRuleRegistry then
      { burnRates: recordedBurnRatesForSLI(sli) }
    else
      { metricFormats: aggregationFormats(sli) }
  );

local targetAggregationSet(sli) =
  aggregationSet.AggregationSet({
    id: 'global_application_sli_%s' % sli.name,
    name: 'Application Defined SLI Global metrics: %s' % sli.name,
    labels: globalLabels + defaultLabels + sli.significantLabels,
    intermediateSource: false,
    generateSLODashboards: false,
    selector: { monitor: 'global' },
    supportedBurnRates: ['5m', '1h'],
    metricFormats: aggregationFormats(sli),
  });

{
  sourceAggregationSet(sli):: sourceAggregationSet(sli),
  targetAggregationSet(sli):: targetAggregationSet(sli),
}
