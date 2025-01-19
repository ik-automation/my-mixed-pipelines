local generateRecordingRulesForMetric(recordingRuleMetric, burnRate, recordingRuleRegistry) =
  if recordingRuleRegistry.recordingRuleForMetricAtBurnRate(metricName=recordingRuleMetric, rangeInterval=burnRate) then
    local expression = recordingRuleRegistry.recordingRuleExpressionFor(metricName=recordingRuleMetric, rangeInterval=burnRate);
    local recordingRuleName = recordingRuleRegistry.recordingRuleNameFor(metricName=recordingRuleMetric, rangeInterval=burnRate);

    [{
      record: recordingRuleName,
      expr: expression,
    }]
  else
    [];

{
  // This generates recording rules for metrics with high-cardinality
  // that are specified in the service catalog under the
  // `recordingRuleMetrics` attribute.
  sliRecordingRulesSetGenerator(
    burnRate,
    recordingRuleRegistry,
  )::
    {
      burnRate: burnRate,

      // Generates the recording rules given a service definition
      generateRecordingRulesForService(serviceDefinition)::
        if std.objectHas(serviceDefinition, 'recordingRuleMetrics') then
          std.flatMap(
            function(recordingRuleMetric) generateRecordingRulesForMetric(recordingRuleMetric, burnRate, recordingRuleRegistry),
            serviceDefinition.recordingRuleMetrics
          )
        else
          [],
    },

}
