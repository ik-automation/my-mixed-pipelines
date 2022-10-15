{
  aggregationSetApdexRatioReflectedRuleSet: (import 'aggregation-set-apdex-ratio-reflected-rule-set.libsonnet').aggregationSetApdexRatioReflectedRuleSet,
  aggregationSetApdexRatioRuleSet: (import 'aggregation-set-apdex-ratio-rule-set.libsonnet').aggregationSetApdexRatioRuleSet,
  aggregationSetErrorRatioRuleSet: (import 'aggregation-set-error-ratio-rule-set.libsonnet').aggregationSetErrorRatioRuleSet,
  aggregationSetErrorRatioReflectedRuleSet: (import 'aggregation-set-error-ratio-reflected-rule-set.libsonnet').aggregationSetErrorRatioReflectedRuleSet,
  aggregationSetRateRuleSet: (import 'aggregation-set-rate-rule-set.libsonnet').aggregationSetRateRuleSet,
  componentMappingRuleSetGenerator: (import 'component-mapping-rule-set-generator.libsonnet').componentMappingRuleSetGenerator,
  componentMetricsRuleSetGenerator: (import 'component-metrics-rule-set-generator.libsonnet').componentMetricsRuleSetGenerator,
  extraRecordingRuleSetGenerator: (import 'extra-recording-rule-set-generator.libsonnet').extraRecordingRuleSetGenerator,
  serviceMappingRuleSetGenerator: (import 'service-mapping-rule-set-generator.libsonnet').serviceMappingRuleSetGenerator,
  serviceSLORuleSetGenerator: (import 'service-slo-rule-set-generator.libsonnet').serviceSLORuleSetGenerator,
  sliRecordingRulesSetGenerator: (import 'sli-recording-rule-set-generator.libsonnet').sliRecordingRulesSetGenerator,
  thresholdHealthRuleSet(threshold): (import 'mwmbr-threshold-health-rule-set.libsonnet').thresholdHealthRuleSet(threshold),
}
