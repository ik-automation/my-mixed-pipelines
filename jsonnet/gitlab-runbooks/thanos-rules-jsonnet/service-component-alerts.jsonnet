local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local serviceAlertsGenerator = import 'slo-alerts/service-alerts-generator.libsonnet';

// Minimum operation rate thresholds:
// This is to avoid low-volume, noisy alerts.
// See docs/metrics-catalog/service-level-monitoring.md for more details
// of how minimumSamplesForMonitoring works
local minimumSamplesForMonitoring = 3600;
local minimumSamplesForNodeMonitoring = 1200;

// 300 requests in 30m required an hour ago before we trigger cessation alerts
// This is about 10 requests per minute, which is not that busy
// The difference between 0.1666 RPS and 0 PRS can occur on calmer periods
local minimumSamplesForTrafficCessation = 300;

// Most MWMBR alerts use a 2m period
// Initially for this alert, use a long period to ensure that
// it's not too noisy.
// Consider bringing this down to 2m after 1 Sep 2020
local nodeAlertWaitPeriod = '10m';

local alertDescriptors = [{
  predicate: function(service) true,
  alertSuffix: '',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service (`{{ $labels.stage }}` stage)',
  alertExtraDetail: null,
  aggregationSet: aggregationSets.componentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: { stage: 'main' },  // Don't alert on cny stage traffic cessation for now
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service) service.nodeLevelMonitoring,
  alertSuffix: 'SingleNode',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service on node `{{ $labels.fqdn }}`',
  alertExtraDetail: 'Since the `{{ $labels.type }}` service is not fully redundant, SLI violations on a single node may represent a user-impacting service degradation.',
  aggregationSet: aggregationSets.nodeComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForNodeMonitoring,  // Note: lower minimum sample rate for node-level monitoring
  alertForDuration: nodeAlertWaitPeriod,
  trafficCessationSelector: {},
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service) service.regional,
  alertSuffix: 'Regional',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service in region `{{ $labels.region }}`',
  alertExtraDetail: 'Note that this alert is specific to the `{{ $labels.region }}` region.',
  aggregationSet: aggregationSets.regionalComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: { stage: 'main' },  // Don't alert on cny stage traffic cessation for now
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}];

local groupsForService(service) = {
  groups: serviceAlertsGenerator(service, alertDescriptors, groupExtras={ partial_response_strategy: 'warn' }),
};

std.foldl(
  function(docs, service)
    docs {
      ['service-level-alerts-%s.yml' % [service.type]]: std.manifestYamlDoc(groupsForService(service)),
    },
  metricsCatalog.services,
  {},
)
