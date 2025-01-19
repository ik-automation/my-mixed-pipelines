local serviceLevelAlerts = import './service-level-alerts.libsonnet';
local sloAlertAnnotations = import './slo-alert-annotations.libsonnet';
local labelsForSLIAlert = import './slo-alert-labels.libsonnet';
local trafficCessationAlertForSLIForAlertDescriptor = import './traffic-cessation-alerts.libsonnet';
local alerts = import 'alerts/alerts.libsonnet';

local apdexAlertForSLIForAlertDescriptor(service, sli, alertDescriptor) =
  local apdexScoreSLO = sli.monitoringThresholds.apdexScore;
  local formatConfig = {
    sliName: sli.name,
    serviceType: service.type,
  };

  serviceLevelAlerts.apdexAlertsForSLI(
    alertName=serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'ApdexSLOViolation' + alertDescriptor.alertSuffix),
    alertTitle=(alertDescriptor.alertTitleTemplate + ' has an apdex violating SLO') % formatConfig,
    alertDescriptionLines=[sli.description] + if alertDescriptor.alertExtraDetail != null then [alertDescriptor.alertExtraDetail] else [],
    serviceType=service.type,
    severity=sli.severity,
    thresholdSLOValue=apdexScoreSLO,
    aggregationSet=alertDescriptor.aggregationSet,
    windows=service.alertWindows,
    metricSelectorHash={ type: service.type, component: sli.name },
    minimumSamplesForMonitoring=alertDescriptor.minimumSamplesForMonitoring,
    alertForDuration=alertDescriptor.alertForDuration,
    extraLabels=labelsForSLIAlert(sli),
    extraAnnotations=sloAlertAnnotations(service.type, sli, alertDescriptor.aggregationSet, 'apdex')
  );

local errorAlertForSLIForAlertDescriptor(service, sli, alertDescriptor) =
  local errorRateSLO = sli.monitoringThresholds.errorRatio;
  local formatConfig = {
    sliName: sli.name,
    serviceType: service.type,
  };

  serviceLevelAlerts.errorAlertsForSLI(
    alertName=serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'ErrorSLOViolation' + alertDescriptor.alertSuffix),
    alertTitle=(alertDescriptor.alertTitleTemplate + ' has an error rate violating SLO') % formatConfig,
    alertDescriptionLines=[sli.description] + if alertDescriptor.alertExtraDetail != null then [alertDescriptor.alertExtraDetail] else [],
    serviceType=service.type,
    severity=sli.severity,
    thresholdSLOValue=errorRateSLO,
    aggregationSet=alertDescriptor.aggregationSet,
    windows=service.alertWindows,
    metricSelectorHash={ type: service.type, component: sli.name },
    minimumSamplesForMonitoring=alertDescriptor.minimumSamplesForMonitoring,
    extraLabels=labelsForSLIAlert(sli),
    alertForDuration=alertDescriptor.alertForDuration,
    extraAnnotations=sloAlertAnnotations(service.type, sli, alertDescriptor.aggregationSet, 'error'),
  );

// Generates an apdex alert for an SLI
local apdexAlertForSLI(service, sli, alertDescriptors) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service) then
        apdexAlertForSLIForAlertDescriptor(service, sli, descriptor)
      else
        [],
    alertDescriptors
  );

// Generates an error rate alert for an SLI
local errorRateAlertsForSLI(service, sli, alertDescriptors) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service) then
        errorAlertForSLIForAlertDescriptor(service, sli, descriptor)
      else
        [],
    alertDescriptors
  );

local trafficCessationAlertsForSLI(service, sli, alertDescriptors) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service) then
        trafficCessationAlertForSLIForAlertDescriptor(service, sli, descriptor)
      else
        [],
    alertDescriptors
  );


local alertsForService(service, alertDescriptors) =
  local slis = service.listServiceLevelIndicators();

  local rules = std.flatMap(
    function(sli)
      (
        if sli.hasApdexSLO() && sli.hasApdex() then
          apdexAlertForSLI(service, sli, alertDescriptors)
        else
          []
      )
      +
      (
        if sli.hasErrorRateSLO() && sli.hasErrorRate() then
          errorRateAlertsForSLI(service, sli, alertDescriptors)
        else
          []
      )
      +
      (
        trafficCessationAlertsForSLI(service, sli, alertDescriptors)
      ),
    slis
  );

  alerts.processAlertRules(rules);


function(service, alertDescriptors, groupExtras={})
  [{
    name: 'Service Component Alerts: %s' % [service.type],
    interval: '1m',
    rules: alertsForService(service, alertDescriptors),
  } + groupExtras]
