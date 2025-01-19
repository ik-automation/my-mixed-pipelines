{
  // The Component Mapping ruleset is used to generate a simple series of
  // static recording rules which are used in alert evaluation to determine whether
  // a component is still being monitored (and should therefore be alerted on)
  //
  // One recording rule is created per component
  componentMappingRuleSetGenerator()::
    {
      // Generates the recording rules given a service definition
      generateRecordingRulesForService(serviceDefinition)::
        [
          {
            local sli = serviceDefinition.serviceLevelIndicators[sliName],
            local serviceAggregation = if sli.serviceAggregation then 'yes' else 'no',
            local regionAggregation = if sli.regional then 'yes' else 'no',

            record: 'gitlab_component_service:mapping',
            labels: {
              type: serviceDefinition.type,
              tier: serviceDefinition.tier,
              service_aggregation: serviceAggregation,
              regional_aggregation: regionAggregation,
              component: sliName,  // Use component for compatability here
            },
            expr: '1',
          }
          for sliName in std.objectFields(serviceDefinition.serviceLevelIndicators)
        ],

    },

}
