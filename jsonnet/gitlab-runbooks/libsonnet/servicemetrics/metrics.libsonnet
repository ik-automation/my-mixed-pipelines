{
  // Metric definitions
  histogramApdex:: (import './histogram_apdex.libsonnet').histogramApdex,
  rateApdex:: (import './rate_apdex.libsonnet').rateApdex,
  combined:: (import './combined.libsonnet').combined,
  customApdex:: (import './custom_apdex.libsonnet').customApdex,
  rateMetric:: (import './rate.libsonnet').rateMetric,
  derivMetric:: (import './rate.libsonnet').derivMetric,
  customRateQuery:: (import './custom_rate_query.libsonnet').customRateQuery,
  gaugeMetric:: (import './gauge_metric.libsonnet').gaugeMetric,

  // Service definition
  serviceDefinition:: (import './service_definition.libsonnet').serviceDefinition,
  serviceLevelIndicatorDefinition:: (import './service_level_indicator_definition.libsonnet').serviceLevelIndicatorDefinition,
  combinedServiceLevelIndicatorDefinition:: (import './combined_service_level_indicator_definition.libsonnet').combinedServiceLevelIndicatorDefinition,

  // Resource Saturation & Utilization definition
  resourceSaturationPoint: (import './resource_saturation_point.libsonnet').resourceSaturationPoint,
  utilizationMetric: (import './utilization_metric.libsonnet').utilizationMetric,

  // Tools for selecting kubernetes resources
  kubeLabelSelectors: (import './kube_label_selectors.libsonnet'),
}
