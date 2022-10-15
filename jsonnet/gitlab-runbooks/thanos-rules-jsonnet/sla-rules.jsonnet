local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';

local keyServices = serviceCatalog.findKeyBusinessServices();

local keyServiceWeights = std.foldl(
  function(memo, item) memo {
    [item.name]: item.business.SLA.overall_sla_weighting,
  }, keyServices, {}
);

local getScoreQuery(weights, interval) =
  local items = [
    'min without(slo) (avg_over_time(slo_observation_status{type="%(type)s", monitor="global"}[%(interval)s])) * %(weight)d' % {
      type: type,
      weight: keyServiceWeights[type],
      interval: interval,
    }
    for type in std.objectFields(weights)
  ];

  std.join('\n  or\n  ', items);

local getWeightQuery(weights, interval) =
  local items = [
    'group without(slo) (avg_over_time(slo_observation_status{type="%(type)s", monitor="global"}[%(interval)s])) * %(weight)d' % {
      type: type,
      weight: keyServiceWeights[type],
      interval: interval,
    }
    for type in std.objectFields(weights)
  ];

  std.join('\n  or\n  ', items);

local weightedIntervalVersions = {
  'weighted_v2.1': '5m',
};

local ruleGroup(version, interval) =
  local labels = {
    sla_type: version,
  };
  {
    name: 'SLA weight calculations - %s' % [version],
    partial_response_strategy: 'warn',
    interval: '1m',
    rules: [{
      // TODO: these are kept for backwards compatability for now
      record: 'sla:gitlab:score',
      labels: labels,
      expr: |||
        sum by (environment, env, stage) (
          %s
        )
      ||| % [getScoreQuery(keyServiceWeights, interval)],
    }, {
      // TODO: these are kept for backwards compatibility for now
      // See https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/309
      record: 'sla:gitlab:weights',
      labels: labels,
      expr: |||
        sum by (environment, env, stage) (
          %s
        )
      ||| % [getWeightQuery(keyServiceWeights, interval)],
    }, {
      record: 'sla:gitlab:ratio',
      labels: labels,
      // Adding a clamp here is a safety precaution. In normal circumstances this should
      // never exceed one. However in incidents such as show,
      // https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/11457
      // there are failure modes where this may occur.
      // Having the clamp_max guard clause can help contain the blast radius.
      expr: |||
        clamp_max(
          sla:gitlab:score{%(selectors)s} / sla:gitlab:weights{%(selectors)s},
          1
        )
      ||| % {
        selectors: selectors.serializeHash(labels { monitor: 'global' }),
      },
    }],
  };

local rules = {
  groups: [
            ruleGroup(version, weightedIntervalVersions[version])
            for version in std.objectFields(weightedIntervalVersions)
          ]
          +
          [{
            name: 'SLA target',
            partial_response_strategy: 'warn',
            interval: '5m',
            rules: [{
              record: 'sla:gitlab:target',
              expr: '%g' % [metricsConfig.slaTarget],
            }],
          }],
};

{
  'sla-rules.yml': std.manifestYamlDoc(rules),
}
