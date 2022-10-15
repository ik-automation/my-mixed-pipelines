local thresholds = import 'mwmbr/thresholds.libsonnet';

local minApdexDeprecatedSingleBurnSLO(labels, expr) =
  {
    record: 'slo:min:gitlab_service_apdex:ratio',
    labels: labels,
    expr: expr,
  };

local maxErrorsDeprecatedSingleBurnSLO(labels, expr) =
  {
    record: 'slo:max:gitlab_service_errors:ratio',
    labels: labels,
    expr: expr,
  };

local maxErrorsMonitoringSLO(labels, expr) =
  {
    record: 'slo:max:events:gitlab_service_errors:ratio',
    labels: labels,
    expr: expr,
  };

local minApdexMonitoringSLO(labels, expr) =
  {
    record: 'slo:min:events:gitlab_service_apdex:ratio',
    labels: labels,
    expr: expr,
  };

local maxErrorsNamedSLO(name, labels, expr) =
  {
    record: thresholds.namedThreshold(name).errorSLO,
    labels: labels,
    expr: expr,
  };

local minApdexNamedSLO(name, labels, expr) =
  {
    record: thresholds.namedThreshold(name).apdexSLO,
    labels: labels,
    expr: expr,
  };

local namedRules(name, serviceDefinition, labels) =
  local thresholds = serviceDefinition.otherThresholds[name];
  [
    if std.objectHas(thresholds, 'apdexScore') then
      minApdexNamedSLO(
        name=name,
        labels=labels,
        expr='%f' % [thresholds.apdexScore],
      )
    else null,
    // Note: the max error rate is `1 - sla` (multiburn)
    if std.objectHas(thresholds, 'errorRatio') then
      maxErrorsNamedSLO(
        name=name,
        labels=labels,
        expr='%f' % [1 - thresholds.errorRatio],
      )
    else null,
  ];

local otherRules(serviceDefinition, labels) =
  local hasOtherThresholds = std.objectHas(serviceDefinition, 'otherThresholds');
  if hasOtherThresholds then
    std.flatMap(
      function(name)
        namedRules(name, serviceDefinition, labels)
      , std.objectFields(serviceDefinition.otherThresholds)
    )
  else [];

local monitoringSLOsPerSLIsForService(serviceDefinition, serviceLabels) =
  std.flatMap(
    function(sli)
      local labels = serviceLabels { component: sli.name };
      [
        if sli.hasApdexSLO() then
          minApdexMonitoringSLO(
            labels=labels,
            expr='%f' % [sli.monitoringThresholds.apdexScore],
          )
        else
          null,
        if sli.hasErrorRateSLO() then
          maxErrorsMonitoringSLO(
            labels=labels,
            expr='%f' % [1 - sli.monitoringThresholds.errorRatio],
          )
        else
          null,
      ],
    serviceDefinition.listServiceLevelIndicators()
  );

local generateServiceSLORules(serviceDefinition) =
  local hasContractualThresholds = std.objectHas(serviceDefinition, 'contractualThresholds');
  local hasMonitoringThresholds = std.objectHas(serviceDefinition, 'monitoringThresholds');

  local triggerDurationLabels = if hasContractualThresholds && std.objectHas(serviceDefinition.contractualThresholds, 'alertTriggerDuration') then
    {
      alert_trigger_duration: serviceDefinition.contractualThresholds.alertTriggerDuration,
    }
  else {};

  local labels = {
    type: serviceDefinition.type,
    tier: serviceDefinition.tier,
  };

  local labelsWithTriggerDurations = labels + triggerDurationLabels;

  local defaultRules = [
    if hasContractualThresholds && std.objectHas(serviceDefinition.contractualThresholds, 'apdexRatio') then
      minApdexDeprecatedSingleBurnSLO(
        labels=labelsWithTriggerDurations,
        expr='%f' % [serviceDefinition.contractualThresholds.apdexRatio]
      )
    else null,

    if hasContractualThresholds && std.objectHas(serviceDefinition.contractualThresholds, 'errorRatio') then
      maxErrorsDeprecatedSingleBurnSLO(
        labels=labelsWithTriggerDurations,
        expr='%f' % [serviceDefinition.contractualThresholds.errorRatio],
      )
    else null,

    // We record an SLO per service and per component:
    //
    // The SLO per service, without a component label is used by some (deprecated)
    // general service alerts in `thanos-rules-jsonnet/service-alerts.jsonnet` and
    // for the Aggregated SLI panels in the service overview dashboard
    //
    // The SLO per component is used by the SLI specific panels in the service overviews
    // Min apdex SLO (multiburn)
    if hasMonitoringThresholds && std.objectHas(serviceDefinition.monitoringThresholds, 'apdexScore') then
      minApdexMonitoringSLO(
        labels=labels,
        expr='%f' % [serviceDefinition.monitoringThresholds.apdexScore],
      )
    else null,

    // Note: the max error rate is `1 - sla` (multiburn)
    if hasMonitoringThresholds && std.objectHas(serviceDefinition.monitoringThresholds, 'errorRatio') then
      maxErrorsMonitoringSLO(
        labels=labels,
        expr='%f' % [1 - serviceDefinition.monitoringThresholds.errorRatio],
      )
    else null,
  ] + monitoringSLOsPerSLIsForService(serviceDefinition, labels);

  std.prune(defaultRules + otherRules(serviceDefinition, labels));

{
  // serviceSLORuleSetGenerator generates static recording rules for recording the current
  // SLO for each service in the metrics catalog.
  // These values are static, but can change over time.
  // They are used for alerting, visualisation and calculating availability.
  serviceSLORuleSetGenerator()::
    {
      // Generates the recording rules given a service definition
      generateRecordingRulesForService(serviceDefinition)::
        generateServiceSLORules(serviceDefinition),
    },

}
