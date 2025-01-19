local aggregationSet = import './aggregation-set.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local fixture1 =
  aggregationSet.AggregationSet({
    intermediateSource: true,
    selector: { x: 'Y' },
    labels: ['common_label_1', 'common_label_2'],
    burnRates: {
      '30m': {
        apdexRatio: 'target_30m_apdex_ratio',
      },
      '1h': {
        apdexRatio: 'target_1h_apdex_ratio',
      },
      '6h': {
        apdexRatio: 'target_6h_apdex_ratio',
      },
      '3d': {
        apdexRatio: 'target_3d_apdex_ratio',
      },
      '1m': {
        apdexRatio: 'target_1m_apdex_ratio',
        apdexWeight: 'target_1m_apdex_weight',
        opsRate: 'target_1m_ops_rate',
        errorRate: 'target_1m_error_rate',
        errorRatio: 'target_1m_error_ratio',
      },
      '5m': {
        apdexRatio: 'target_5m_apdex_ratio',
      },
    },
  });

local generatedFixture = aggregationSet.AggregationSet({
  selector: { x: 'Y' },
  intermediateSource: false,
  labels: ['common_label_1', 'common_label_2'],
  generateSLODashboards: false,
  supportedBurnRates: ['1m', '5m'],
  metricFormats: {
    apdexSuccessRate: 'target_generated_%s_success_rate',
    apdexRatio: 'target_generated_%s_apdex_ratio',
    apdexWeight: 'target_generated_%s_apdex_weight',
    opsRate: 'target_generated_%s_ops_rate',
    errorRate: 'target_generated_%s_error_rate',
    errorRatio: 'target_generated_%s_error_ratio',
  },
});

local mixedFixture = aggregationSet.AggregationSet(fixture1 {
  supportedBurnRates: ['17d'],
  metricFormats: {
    apdexRatio: 'target_generated_%s_apdex_ratio',
  },
});

local isValid(definition) =
  aggregationSet._UnvalidatedAggregationSet(definition).isValid(definition);

test.suite({
  testDefaults: {
    actual: fixture1.aggregationFilter,
    expect: null,
  },
  testDefaultSupportedBurnRates: {
    actual: fixture1.supportedBurnRates,
    expect: ['5m', '30m', '1h'],
  },
  testAggregationFilter: {
    actual: aggregationSet.AggregationSet(fixture1 { aggregationFilter: 'regional' }).aggregationFilter,
    expect: 'regional',
  },

  // Fixture with hardcoded metric names
  testGetApdexRatioMetricForBurnRate: {
    actual: fixture1.getApdexRatioMetricForBurnRate('1m'),
    expect: 'target_1m_apdex_ratio',
  },
  testGetApdexWeightMetricForBurnRate: {
    actual: fixture1.getApdexWeightMetricForBurnRate('1m'),
    expect: 'target_1m_apdex_weight',
  },
  testGetOpsRateMetricForBurnRate: {
    actual: fixture1.getOpsRateMetricForBurnRate('1m'),
    expect: 'target_1m_ops_rate',
  },
  testGetErrorRateMetricForBurnRate: {
    actual: fixture1.getErrorRateMetricForBurnRate('1m'),
    expect: 'target_1m_error_rate',
  },
  testGetErrorRatioMetricForBurnRate: {
    actual: fixture1.getErrorRatioMetricForBurnRate('1m'),
    expect: 'target_1m_error_ratio',
  },
  testMissingErrorRatioMetricForBurnRate: {
    actual: fixture1.getErrorRatioMetricForBurnRate('5m'),
    expect: null,
  },
  testGetBurnRates: {
    actual: fixture1.getBurnRates(),
    expect: ['1m', '5m', '30m', '1h', '6h', '3d'],
  },

  // A fixture with generated metric names
  testGetGeneratedApdexRatioMetricForBurnRate: {
    actual: generatedFixture.getApdexRatioMetricForBurnRate('1m'),
    expect: 'target_generated_1m_apdex_ratio',
  },
  testGetGenratedApdexWeightMetricForBurnRate: {
    actual: generatedFixture.getApdexWeightMetricForBurnRate('5m'),
    expect: 'target_generated_5m_apdex_weight',
  },
  testGetGeneratedOpsRateMetricForBurnRate: {
    actual: generatedFixture.getOpsRateMetricForBurnRate('1m'),
    expect: 'target_generated_1m_ops_rate',
  },
  testGetGeneratedErrorRateMetricForBurnRate: {
    actual: generatedFixture.getErrorRateMetricForBurnRate('1m'),
    expect: 'target_generated_1m_error_rate',
  },
  testGetGeneratedErrorRatioMetricForBurnRate: {
    actual: generatedFixture.getErrorRatioMetricForBurnRate('1m'),
    expect: 'target_generated_1m_error_ratio',
  },
  testMissingGeneratedErrorRatioMetricForBurnRate: {
    actual: generatedFixture.getErrorRatioMetricForBurnRate('10m'),
    expect: null,
  },
  testGetGeneratedBurnRates: {
    actual: generatedFixture.getBurnRates(),
    expect: ['1m', '5m'],
  },

  // Tests the edge cases for fixture with mixed hardcoded & generated metric names
  testMixedGeneratedMetricForBurnRate: {
    actual: mixedFixture.getApdexRatioMetricForBurnRate('17d'),
    expect: 'target_generated_17d_apdex_ratio',
  },
  testMixedGeneratedOverriddenBurnRate: {
    actual: mixedFixture.getApdexWeightMetricForBurnRate('5m'),
    expect: null,
  },
  testMixedGeneratedGetBurnRates: {
    actual: mixedFixture.getBurnRates(),
    expect: ['1m', '5m', '30m', '1h', '6h', '3d', '17d'],
  },

  testValidBurnRatesDashboard: {
    actual: isValid({
      labels: [],
      selector: {},
      upscaleLongerBurnRates: false,
      generateSLODashboards: true,
      supportedBurnRates: ['1m', '5m', '30m', '1h', '6h', '3d'],
    }),
    expect: true,
  },

  testValidBurnRatesNoDashboard: {
    actual: isValid({
      labels: [],
      selector: {},
      upscaleLongerBurnRates: false,
      generateSLODashboards: false,
      supportedBurnRates: ['1m'],
    }),
    expect: true,
  },

  testInvalidBurnRatesDashboard: {
    actual: isValid({
      labels: [],
      selector: {},
      upscaleLongerBurnRates: false,
      generateSLODashboards: true,
      supportedBurnRates: ['1m'],
    }),
    expect: false,
  },

  testInvalidBurnRatesNoDashboard: {
    actual: isValid({
      labels: [],
      selector: {},
      upscaleLongerBurnRates: false,
      generateSLODashboards: false,
      supportedBurnRates: [1],
    }),
    expect: false,
  },

  testGetBurnRatesByType: {
    actual: fixture1.getBurnRatesByType(),
    expect: {
      fast: ['1m', '5m', '1h'],
      slow: ['30m', '6h', '3d'],
    },
  },

  testGetAllMetricNames: {
    actual: fixture1.getAllMetricNames(),
    expect: [
      'target_1m_apdex_ratio',
      'target_1m_apdex_weight',
      'target_1m_error_rate',
      'target_1m_error_ratio',
      'target_1m_ops_rate',
      'target_5m_apdex_ratio',
      'target_30m_apdex_ratio',
      'target_1h_apdex_ratio',
      'target_6h_apdex_ratio',
      'target_3d_apdex_ratio',
    ],
  },
})
