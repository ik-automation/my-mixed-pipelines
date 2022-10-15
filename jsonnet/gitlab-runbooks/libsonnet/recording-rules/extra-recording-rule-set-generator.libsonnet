{
  // The extraRecordingRuleSetGenerator rule set will generate recording rules specified in the
  // extraRecordingRulesPerBurnRate attribute on a service definition.
  // This can be useful when recording rules rely on other recording rules
  // and we want to avoid evaluation occurring out-of-phase
  extraRecordingRuleSetGenerator(burnRate)::
    {
      // Generates the recording rules given a service definition
      generateRecordingRulesForService(serviceDefinition)::
        if std.objectHas(serviceDefinition, 'extraRecordingRulesPerBurnRate') then
          std.flatMap(function(r) r(burnRate), serviceDefinition.extraRecordingRulesPerBurnRate)
        else
          [],
    },

}
