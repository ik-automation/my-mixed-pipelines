local periodicQuery = import './periodic-query.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';

local defaultSelector = {
  env: { re: 'ops|gprd' },
  environment: 'gprd',
  stage: 'main',
  monitor: 'global',
};
local interval = '1d';
local keyServiceNames = std.map(
  function(service) service.name,
  serviceCatalog.findKeyBusinessServices(includeZeroScore=true)
);

{
  overall_ratio: periodicQuery.new({
    query: |||
      avg_over_time(sla:gitlab:ratio{%(selectors)s}[%(interval)s])
    ||| % {
      selectors: selectors.serializeHash(defaultSelector),
      interval: interval,
    },
  }),
  service_ratio: periodicQuery.new({
    query: |||
      avg by (type) (
        avg_over_time(slo_observation_status{%(selectors)s}[%(interval)s])
      )
    ||| % {
      selectors: selectors.serializeHash(defaultSelector {
        type: { re: std.join('|', keyServiceNames) },
      }),
      interval: interval,
    },
  }),
  overall_target: periodicQuery.new({
    query: "sla:gitlab:target{monitor='global'}",
  }),
}
