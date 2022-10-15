local allUtilizationMetrics = (import 'gitlab-metrics-config.libsonnet').utilizationMonitoring;

allUtilizationMetrics {
  // Add some helpers. Note that these use :: to "hide" then:

  /**
   * Given a service (identified by `type`) returns a list of resources that
   * are monitored for that type
   */
  listApplicableServicesFor(type)::
    std.filter(function(k) self[k].appliesToService(type), std.objectFields(self)),

  // Iterate over resources, calling the mapping function with (name, definition)
  mapUtilizationMetrics(mapFunc)::
    std.map(function(utilizationMetricName) mapFunc(utilizationMetricName, self[utilizationMetricName]), std.objectFields(self)),
}
