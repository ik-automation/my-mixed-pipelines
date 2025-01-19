local serviceDefinition = import './service_definition.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testInheritedMonitoringThresholds: {
    actual: serviceDefinition.serviceDefinition({
      monitoringThresholds: {
        apdexScore: 0.998,
        errorRatio: 0.999,
      },
      serviceLevelIndicators: {
        fancy: {
          userImpacting: false,
          requestRate: {},
          significantLabels: [],
        },
      },
    }).serviceLevelIndicators.fancy.monitoringThresholds,
    expect: {
      apdexScore: 0.998,
      errorRatio: 0.999,
    },
  },

  testSLISpecifiedThresholds: {
    actual: serviceDefinition.serviceDefinition({
      monitoringThresholds: {
        apdexScore: 0.998,
        errorRatio: 0.999,
      },
      serviceLevelIndicators: {
        fancy: {
          userImpacting: false,
          requestRate: {},
          significantLabels: [],
          monitoringThresholds+: {
            apdexScore: 0.95,
            errorRatio: 0.99,
          },
        },
      },
    }).serviceLevelIndicators.fancy.monitoringThresholds,
    expect: {
      apdexScore: 0.95,
      errorRatio: 0.99,
    },
  },

  testMixedMonitoringThresholds: {
    actual: serviceDefinition.serviceDefinition({
      monitoringThresholds: {
        apdexScore: 0.998,
        errorRatio: 0.999,
      },
      serviceLevelIndicators: {
        fancy: {
          userImpacting: false,
          requestRate: {},
          significantLabels: [],
          monitoringThresholds+: {
            errorRatio: 0.99,
          },
        },
      },
    }).serviceLevelIndicators.fancy.monitoringThresholds,
    expect: {
      apdexScore: 0.998,
      errorRatio: 0.99,
    },
  },
})
