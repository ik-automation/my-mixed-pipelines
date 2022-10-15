local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

// Merge two hashes of the form { key: set },
local merge(h1, h2) =
  local folderFunc = function(memo, k)
    if std.objectHas(memo, k) then
      memo {
        [k]: {
          labels: std.setUnion(memo[k].labels, h2[k].labels),
          burnRates: std.setUnion(memo[k].burnRates, h2[k].burnRates),
        },
      }
    else
      memo {
        [k]: h2[k],
      };

  std.foldl(folderFunc, std.objectFields(h2), h1);

local mergeFoldl(fn, array) =
  std.foldl(function(memo, item) merge(memo, fn(item)), array, {});

local collectMetricsBurnRatesLabelsForKeyMetric(sli, keyMetricAttribute, significantLabels) =
  // Check the sli supports the key metric `keyMetricAttribute`
  if std.objectHas(sli, keyMetricAttribute) then
    local keyMetric = sli[keyMetricAttribute];

    // Does the key metric support reflection?
    if std.objectHasAll(keyMetric, 'supportsReflection') then
      local reflection = sli[keyMetricAttribute].supportsReflection();
      local metricNamesAndLabels = reflection.getMetricNamesAndLabels();
      std.foldl(
        function(memo, metricName) memo {
          [metricName]: {
            labels: std.setUnion(significantLabels, metricNamesAndLabels[metricName]),
            burnRates: if sli.upscaleLongerBurnRates then std.set(['1m', '5m', '30m', '1h']) else std.set(['1m', '5m', '30m', '1h', '6h']),
          },
        },
        std.objectFields(metricNamesAndLabels),
        {}
      )
    else
      {}
  else
    {};

// Return a hash of { metric: set(labels) } for an SLI
local collectMetricsAndLabelsForSLI(sli) =
  local significantLabels = std.set(sli.significantLabels);

  mergeFoldl(function(keyMetricAttribute)
               collectMetricsBurnRatesLabelsForKeyMetric(sli, keyMetricAttribute, significantLabels),
             ['apdex', 'requestRate', 'errorRate']);

// Return a hash of { metric: set(labels) } for a service
local collectMetricsLabelsBurnRatesForService(service) =
  local foldFunc = function(memo, sliName)
    local sli = service.serviceLevelIndicators[sliName];
    merge(memo, collectMetricsAndLabelsForSLI(sli));

  std.foldl(foldFunc, std.objectFields(service.serviceLevelIndicators), {});

// Return a hash of metrics and dimensions, for use in composing recording rules
local collectMetricsLabelsBurnRates() =
  local foldFunc = function(memo, service)
    merge(memo, collectMetricsLabelsBurnRatesForService(service));
  std.foldl(foldFunc, metricsCatalog.services, {});

local labelsBurnRatesForMetricNames = collectMetricsLabelsBurnRates();

{
  // Returns a set of label names used for the given metric name
  lookupLabelsForMetricName(metricName)::
    if std.objectHas(labelsBurnRatesForMetricNames, metricName) then
      labelsBurnRatesForMetricNames[metricName].labels
    else
      [],

  supportsBurnRateForMetricName(metricName, burnRate)::
    if std.objectHas(labelsBurnRatesForMetricNames, metricName) then
      std.member(labelsBurnRatesForMetricNames[metricName].burnRates, burnRate)
    else
      false,

  getSupportedBurnRatesForMetricName(metricName)::
    if std.objectHas(labelsBurnRatesForMetricNames, metricName) then
      labelsBurnRatesForMetricNames[metricName].burnRates
    else
      [],
}
