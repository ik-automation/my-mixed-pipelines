local allSaturationResources = (import 'gitlab-metrics-config.libsonnet').saturationMonitoring;

allSaturationResources {
  // Add some helpers. Note that these use :: to "hide" then:

  /**
   * Given a service (identified by `type`) returns a list of resources that
   * are monitored for that type
   */
  listApplicableServicesFor(type)::
    std.filter(function(k) self[k].appliesToService(type), std.objectFields(self)),

  // Iterate over resources, calling the mapping function with (name, definition)
  mapResources(mapFunc)::
    std.map(function(saturationName) mapFunc(saturationName, self[saturationName]), std.objectFields(self)),
}
