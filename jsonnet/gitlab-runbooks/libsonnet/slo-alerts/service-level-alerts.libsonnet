local multiburnExpression = import 'mwmbr/expression.libsonnet';
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local minimumOpRate = import 'slo-alerts/minimum-op-rate.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';
local strings = import 'utils/strings.libsonnet';

local labelsForAlert(severity, aggregationSet, sliType, alertClass, windowDuration) =
  local pager = if severity == 's1' || severity == 's2' then 'pagerduty' else null;

  {
    alert_class: alertClass,
    aggregation: aggregationSet.id,
    sli_type: sliType,
    rules_domain: 'general',
    severity: severity,
    pager: pager,
    [if windowDuration != null then 'window']: windowDuration,
    // slo_alert same as alert_type, consider dropping
    slo_alert: if sliType == 'apdex' || sliType == 'error' then 'yes' else 'no',
    alert_type: if sliType == 'apdex' || sliType == 'error' then 'symptom' else 'cause',
  };

// Generates an alert name
local nameSLOViolationAlert(serviceType, sliName, violationType) =
  '%(serviceType)sService%(sliName)s%(violationType)s' % {
    serviceType: strings.toCamelCase(serviceType),
    sliName: strings.toCamelCase(sliName),
    violationType: violationType,
  };

local ignoredGrafanaVariables = std.set(['tier', 'env']);

// Generates some common annotations for each SLO alert
local commonAnnotations(serviceType, aggregationSet, metricName) =
  local formatConfig = {
    serviceType: serviceType,
    metricName: metricName,
    aggregationId: aggregationSet.id,
  };

  local grafanaVariables = std.filter(function(l) !std.member(ignoredGrafanaVariables, l), aggregationSet.labels);

  {
    runbook: 'docs/%(serviceType)s/README.md' % formatConfig,  // We can do better than this
    grafana_dashboard_id: 'alerts-%(aggregationId)s_slo_%(metricName)s' % formatConfig,
    grafana_panel_id: stableIds.hashStableId('multiwindow-multiburnrate'),
    grafana_variables: std.join(',', grafanaVariables),
    grafana_min_zoom_hours: '6',
  };

local getAlertForDurationWithDefault(alertForDuration, windows) =
  if alertForDuration == null then
    multiburnFactors.alertForDurationForLongThreshold(windows[0])
  else
    alertForDuration;

// Generates an apdex alert
local apdexAlertsForSLI(
  alertName,  // `alert` label for the alert (ie, the name)
  alertTitle,  // Title annotation
  alertDescriptionLines,  // Description annotation
  serviceType,  // The type of the service this is associated with
  severity,  // The severity of the alert
  thresholdSLOValue,  // The SLO alert threshold
  aggregationSet,  // The aggregation set
  windows,  // Array of long window durations for the alert
  metricSelectorHash,  // Additional selectors to apply to the query
  minimumSamplesForMonitoring=null,  // Minimum sample rate threshold: see docs/metrics-catalog/service-level-monitoring.md
  alertForDuration=null,  // Use the default `for` alert duration
  extraLabels={},  // Extra labels for the alert
  extraAnnotations={},  // Extra annotations for the alert
      ) =

  local alertForDurationWithDefault = getAlertForDurationWithDefault(alertForDuration, windows);

  [
    {
      alert: alertName,
      expr: multiburnExpression.multiburnRateApdexExpression(
        aggregationSet=aggregationSet,
        metricSelectorHash=metricSelectorHash,
        requiredOpRate=minimumOpRate.calculateFromSamplesForDuration(windowDuration, minimumSamplesForMonitoring),
        thresholdSLOValue=thresholdSLOValue,
        windows=[windowDuration],
        operationRateWindowDuration=windowDuration,
      ),
      'for': alertForDurationWithDefault,
      labels: labelsForAlert(severity, aggregationSet, 'apdex', 'slo_violation', windowDuration) + extraLabels,
      annotations: commonAnnotations(serviceType, aggregationSet, 'apdex') {
        title: alertTitle,
        description: strings.markdownParagraphs(
          alertDescriptionLines +
          ['Currently the apdex value is {{ $value | humanizePercentage }}.']
        ),
      } + extraAnnotations,
    }
    for windowDuration in windows
  ];

// Generates an error alert
local errorAlertsForSLI(
  alertName,  // `alert` label for the alert (ie, the name)
  alertTitle,  // Title annotation
  alertDescriptionLines,  // Description annotation
  serviceType,  // The type of the service this is associated with
  severity,  // The severity of the alert
  thresholdSLOValue,  // The SLO alert threshold
  aggregationSet,  // The aggregation set
  windows,  // Array of long window durations for the alert
  metricSelectorHash,  // Additional selectors to apply to the query
  minimumSamplesForMonitoring=null,  // Minimum sample rate threshold see docs/metrics-catalog/service-level-monitoring.md
  alertForDuration=null,  // Use the default `for` alert duration
  extraLabels={},  // Extra labels for the alert
  extraAnnotations={},  // Extra annotations for the alert
      ) =

  local alertForDurationWithDefault = getAlertForDurationWithDefault(alertForDuration, windows);

  [
    {
      alert: alertName,
      expr: multiburnExpression.multiburnRateErrorExpression(
        aggregationSet=aggregationSet,
        metricSelectorHash=metricSelectorHash,
        requiredOpRate=minimumOpRate.calculateFromSamplesForDuration(windowDuration, minimumSamplesForMonitoring),
        thresholdSLOValue=1 - thresholdSLOValue,
        windows=[windowDuration],
        operationRateWindowDuration=windowDuration,
      ),
      'for': alertForDurationWithDefault,
      labels: labelsForAlert(severity, aggregationSet, 'error', 'slo_violation', windowDuration) + extraLabels,
      annotations: commonAnnotations(serviceType, aggregationSet, 'error') {
        title: alertTitle,
        description: strings.markdownParagraphs(
          alertDescriptionLines +
          ['Currently the error-rate is {{ $value | humanizePercentage }}.']
        ),
      } + extraAnnotations,
    }
    for windowDuration in windows
  ];

{
  nameSLOViolationAlert:: nameSLOViolationAlert,
  labelsForAlert:: labelsForAlert,
  commonAnnotations:: commonAnnotations,
  apdexAlertsForSLI:: apdexAlertsForSLI,
  errorAlertsForSLI:: errorAlertsForSLI,
}
