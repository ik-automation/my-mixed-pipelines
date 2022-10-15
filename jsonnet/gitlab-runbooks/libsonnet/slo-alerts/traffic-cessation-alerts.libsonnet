local minimumOpRate = import './minimum-op-rate.libsonnet';
local serviceLevelAlerts = import './service-level-alerts.libsonnet';
local sloAlertAnnotations = import './slo-alert-annotations.libsonnet';
local labelsForSLIAlert = import './slo-alert-labels.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local durationParser = import 'utils/duration-parser.libsonnet';
local strings = import 'utils/strings.libsonnet';

// This function is used to generate the SLI alert annotations.
local annotationsForTrafficAlert(service, sli, alertDescriptor, aggregationSet, partialTitle, description) =
  local formatConfig = {
    sliName: sli.name,
    serviceType: service.type,
  };

  serviceLevelAlerts.commonAnnotations(service.type, aggregationSet, 'ops') +
  sloAlertAnnotations(service.type, sli, aggregationSet, 'ops') +
  {
    title: (alertDescriptor.alertTitleTemplate % formatConfig) + ' ' + partialTitle,
    description: strings.markdownParagraphs(
      [
        strings.chomp(sli.description),
        description,
      ] +
      if alertDescriptor.alertExtraDetail != null then [alertDescriptor.alertExtraDetail] else []
    ),
  };

local trafficCessationRequiredOpRateFormat(requiredOpRate) =
  if requiredOpRate == null then
    ''
  else
    |||
      and
      %(opsRateIntermediateMetric)s{%(selector)s} offset 1h >= %(requiredOpRate)s
    |||;


local getTrafficCessationAlertSelector(service, sli, alertDescriptor) =
  local aggregationSet = alertDescriptor.aggregationSet;
  local aggregationSetId = aggregationSet.id;
  local sliTrafficCessationConfig = sli.trafficCessationAlertConfig;

  if sli.trafficCessationAlertConfig == false then
    null
  else if sli.trafficCessationAlertConfig == true then
    {}
  else if std.isObject(sliTrafficCessationConfig) then
    if std.objectHas(sliTrafficCessationConfig, aggregationSetId) then
      local aggregationSetValue = sliTrafficCessationConfig[aggregationSetId];
      if aggregationSetValue == false then
        null
      else if aggregationSetValue == true then
        {}
      else
        aggregationSetValue
    else
      {}
  else
    error 'Invalid traffic cessation config';

// Generates traffic cessation alerts for a service/sli/alertDescriptor combination
local generateTrafficCessationAlerts(service, sli, alertDescriptor, trafficCessationAlertSelector) =
  local aggregationSet = alertDescriptor.aggregationSet;

  // Returns burn rate periods, in order of ascending duration
  // Exclude the legacy 1m period
  local burnRates = std.filter(function(f) durationParser.toSeconds(f) > 60, aggregationSet.getBurnRates());

  // The short period is the shortest period, excluding the legacy 1m period (usually 5m)
  local opsRateShortPeriod = burnRates[0];
  local opsRateShortMetric = aggregationSet.getOpsRateMetricForBurnRate(opsRateShortPeriod, required=false);

  // The intermediate period is the second longest burn rate (usually 30m)
  local opsRateIntermediatePeriod = burnRates[1];
  local opsRateIntermediateMetric = aggregationSet.getOpsRateMetricForBurnRate(opsRateIntermediatePeriod, required=false);

  local aggregationSetSelector = aggregationSet.selector;

  local selector = {
                     type: service.type,
                     component: sli.name,
                   } + aggregationSetSelector
                   + alertDescriptor.trafficCessationSelector
                   + trafficCessationAlertSelector;

  local formatConfig = {
    opsRateShortPeriod: opsRateShortPeriod,
    opsRateShortMetric: opsRateShortMetric,
    opsRateIntermediatePeriod: opsRateIntermediatePeriod,
    opsRateIntermediateMetric: opsRateIntermediateMetric,
    selector: selectors.serializeHash(selector),
  };

  local requiredOpRate = minimumOpRate.calculateFromSamplesForDuration(
    duration=opsRateIntermediatePeriod,
    sampleCount=alertDescriptor.minimumSamplesForTrafficCessation
  );

  // TrafficCessation and TrafficAbsent alerts use the same labels, for easier matching
  local labelsForTrafficAlerts =
    serviceLevelAlerts.labelsForAlert(sli.severity, aggregationSet, 'ops', 'traffic_cessation', windowDuration=null)
    +
    labelsForSLIAlert(sli);

  (if opsRateIntermediateMetric != null then
     [{
       local expr = |||
         %(opsRateIntermediateMetric)s{%(selector)s} == 0
       ||| + trafficCessationRequiredOpRateFormat(requiredOpRate),

       alert: serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'TrafficCessation' + alertDescriptor.alertSuffix),
       expr: expr % formatConfig {
         requiredOpRate: requiredOpRate,
       },
       'for': opsRateShortPeriod,
       labels: labelsForTrafficAlerts,
       annotations:
         annotationsForTrafficAlert(
           service,
           sli,
           alertDescriptor,
           aggregationSet,
           partialTitle='has not received any traffic in the past %(opsRateIntermediatePeriod)s' % formatConfig,
           description='This alert signifies that the SLI is reporting a cessation of traffic; the signal is present, but is zero.'
         ),
     }] else [])
  +
  (if opsRateShortMetric != null then
     [{
       alert: serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'TrafficAbsent' + alertDescriptor.alertSuffix),
       expr: |||
         %(opsRateShortMetric)s{%(selector)s} offset 1h
         unless
         %(opsRateShortMetric)s{%(selector)s}
       ||| % formatConfig,
       'for': opsRateIntermediatePeriod,
       labels: labelsForTrafficAlerts,
       annotations:
         annotationsForTrafficAlert(
           service,
           sli,
           alertDescriptor,
           aggregationSet,
           partialTitle='has not reported any traffic in the past %(opsRateIntermediatePeriod)s' % formatConfig,
           description=|||
             This alert signifies that the SLI was previously reporting traffic, but is no longer - the signal is absent.

             This could be caused by a change to the metrics used in the SLI, or by the service not receiving traffic.
           |||
         ),
     }] else []);

function(service, sli, alertDescriptor)
  local trafficCessationAlertSelector = getTrafficCessationAlertSelector(service, sli, alertDescriptor);

  // null selector means no traffic cessation alerts for this SLI/aggregationset combination
  if trafficCessationAlertSelector != null then
    generateTrafficCessationAlerts(service, sli, alertDescriptor, trafficCessationAlertSelector)
  else []
