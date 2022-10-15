local thresholds = import './thresholds.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testNamedThreshold: {
    actual: thresholds.namedThreshold('hello_world'),
    expect: {
      name: 'hello_world',
      errorSLO: 'slo:max:hello_world:gitlab_service_errors:ratio',
      apdexSLO: 'slo:min:hello_world:gitlab_service_apdex:ratio',
      errorHealth: 'gitlab_hello_world_health:service:errors',
      apdexHealth: 'gitlab_hello_world_health:service:apdex',
      aggregateServiceHealth: 'gitlab_hello_world_health:service',
      aggregateStageHealth: 'gitlab_hello_world_health:stage',
    },
  },
  testKnownOtherThresholds: {
    actual: std.map(function(t) t.name, thresholds.knownOtherThresholds),
    expect: ['deployment', 'mtbf'],
  },
})
