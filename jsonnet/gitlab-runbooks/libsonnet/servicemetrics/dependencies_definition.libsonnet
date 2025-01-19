local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

// Validate component and type exists.
// Validate component and type match.
local validateAndApplyDefaults(type, sliName, dependsOn) =
  std.foldl(
    function(_, dependency)
      assert metricsCatalog.serviceExists(dependency.type) :
             '`dependsOn.type` field invalid for "%s": service "%s" does not exist' % [sliName, dependency.type];
      assert std.objectHas(metricsCatalog.getService(dependency.type).serviceLevelIndicators, dependency.component) :
             '`dependsOn.component` field invalid for "%s": component "%s" does not exist for service "%s"' % [sliName, dependency.component, dependency.type];
      // https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/15971
      assert type != dependency.type :
             'inhibit rule creation failed: `dependsOn.type` for the sli "%s.%s" cannot depend on an sli of the same service ("%s")' % [dependency.type, sliName, type];
      dependsOn,
    dependsOn,
    [],
  );

{
  new(type, sliName, dependsOn):: {
    local dependsOnWithDefaults = validateAndApplyDefaults(type, sliName, dependsOn),

    generateInhibitionRules():: [
      {
        assert metricsCatalog.serviceExists(type) :
               'dependency definition failed: type "%s" does not exist' % [type],
        assert std.objectHas(metricsCatalog.getService(type).serviceLevelIndicators, sliName) :
               'dependency definition failed: sliName "%s" does not exist' % [sliName],
        target_matchers: selectors.alertManagerMatchers({
          type: type,
          component: sliName,
        }),
        source_matchers: selectors.alertManagerMatchers({
          type: dependency.type,
          component: dependency.component,
        }),
        equal: ['env', 'environment', 'pager'],
      }
      for dependency in dependsOnWithDefaults
    ],
  },
}
