local multiburnFactors = import './multiburn_factors.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testBurnTypeForWindow_fast: {
    actual: multiburnFactors.burnTypeForWindow('1h'),
    expect: 'fast',
  },
  testBurnTypeForWindow_slow: {
    actual: multiburnFactors.burnTypeForWindow('30m'),
    expect: 'slow',
  },
  testBurnTypeForWindow_missingFast: {
    actual: multiburnFactors.burnTypeForWindow('1m'),
    expect: 'fast',
  },
  testBurnTypeForWindow_missingSlow: {
    actual: multiburnFactors.burnTypeForWindow('28d'),
    expect: 'slow',
  },

  // See https://landing.google.com/sre/workbook/chapters/alerting-on-slos/#5-multiple-burn-rate-alerts
  // for more details
  testErrorBudgetFactorFor_1h: {
    actual: multiburnFactors.errorBudgetFactorFor('1h'),
    expect: 14.4,
  },
  testErrorBudgetFactorFor_6h: {
    actual: multiburnFactors.errorBudgetFactorFor('6h'),
    expect: 6,
  },
  testErrorBudgetFactorFor_3d: {
    actual: multiburnFactors.errorBudgetFactorFor('3d'),
    expect: 1,
  },
  testErrorRatioThreshold1h: {
    actual: '%g' % [multiburnFactors.errorRatioThreshold(0.9995, windowDuration='1h')],
    expect: '%g' % [0.0072],
  },
  testErrorRatioThreshold6h: {
    actual: '%g' % [multiburnFactors.errorRatioThreshold(0.9995, windowDuration='6h')],
    expect: '%g' % [0.003],
  },
  testApdexRatioThreshold1h: {
    actual: '%g' % [multiburnFactors.apdexRatioThreshold(0.9995, windowDuration='1h')],
    expect: '%g' % [0.9928],
  },
  testApdexRatioThreshold6h: {
    actual: '%g' % [multiburnFactors.apdexRatioThreshold(0.9995, windowDuration='6h')],
    expect: '%g' % [0.997],
  },
})
