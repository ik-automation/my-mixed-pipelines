local expression = import './expression.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';

local testAggregationSet = aggregationSet.AggregationSet({
  name: 'Test',
  intermediateSource: false,
  selector: { monitor: 'global' },  // Not Thanos Ruler
  labels: ['environment', 'tier', 'type', 'stage'],
  burnRates: {
    '5m': {
      apdexRatio: 'apdex:ratio_5m',
      apdexWeight: 'apdex:weight:score_5m',
      opsRate: 'operation:rate_5m',
      errorRate: 'error:rate_5m',
      errorRatio: 'error:ratio_5m',
    },
    '30m': {
      apdexRatio: 'apdex:ratio_30m',
      apdexWeight: 'apdex:weight:score_30m',
      opsRate: 'operation:rate_30m',
      errorRate: 'error:rate_30m',
      errorRatio: 'error:ratio_30m',
    },
    '1h': {
      apdexRatio: 'apdex:ratio_1h',
      apdexWeight: 'apdex:weight:score_1h',
      opsRate: 'operation:rate_1h',
      errorRate: 'error:rate_1h',
      errorRatio: 'error:ratio_1h',
    },
    '6h': {
      apdexRatio: 'apdex:ratio_6h',
      apdexWeight: 'apdex:weight:score_6h',
      opsRate: 'operation:rate_6h',
      errorRate: 'error:rate_6h',
      errorRatio: 'error:ratio_6h',
    },
    '3d': {
      apdexRatio: 'apdex:ratio_3d',
      apdexWeight: 'apdex:weight:score_3d',
      opsRate: 'operation:rate_3d',
      errorRate: 'error:rate_3d',
      errorRatio: 'error:ratio_3d',
    },
  },
});


test.suite({
  testErrorBurnWithoutMinimumRate: {
    actual: expression.multiburnRateErrorExpression(
      aggregationSet=testAggregationSet,
      thresholdSLOValue=0.99,
      metricSelectorHash={ type: 'web' },
    ),
    expect: |||
      (
        error:ratio_1h{monitor="global",type="web"}
        > (14.4 * 0.990000)
      )
      and
      (
        error:ratio_5m{monitor="global",type="web"}
        > (14.4 * 0.990000)
      )
      or
      (
        error:ratio_6h{monitor="global",type="web"}
        > (6 * 0.990000)
      )
      and
      (
        error:ratio_30m{monitor="global",type="web"}
        > (6 * 0.990000)
      )
    |||,
  },

  testErrorBurnWithThreshold: {
    actual: expression.multiburnRateErrorExpression(
      aggregationSet=testAggregationSet,
      metricSelectorHash={ type: 'web' },
      requiredOpRate=10,
      thresholdSLOValue=0.01,
    ),
    expect: |||
      (
        (
          error:ratio_1h{monitor="global",type="web"}
          > (14.4 * 0.010000)
        )
        and
        (
          error:ratio_5m{monitor="global",type="web"}
          > (14.4 * 0.010000)
        )
        or
        (
          error:ratio_6h{monitor="global",type="web"}
          > (6 * 0.010000)
        )
        and
        (
          error:ratio_30m{monitor="global",type="web"}
          > (6 * 0.010000)
        )
      )
      and on(environment,tier,type,stage)
      (
        sum by(environment,tier,type,stage) (operation:rate_1h{monitor="global",type="web"}) >= 10
      )
    |||,
  },

  testApdexBurnWithoutMinimumRate: {
    actual: expression.multiburnRateApdexExpression(
      aggregationSet=testAggregationSet,
      metricSelectorHash={ type: 'web' },
      thresholdSLOValue=0.99,
    ),
    expect: |||
      (
        apdex:ratio_1h{monitor="global",type="web"}
        < (1 - 14.4 * 0.010000)
      )
      and
      (
        apdex:ratio_5m{monitor="global",type="web"}
        < (1 - 14.4 * 0.010000)
      )
      or
      (
        apdex:ratio_6h{monitor="global",type="web"}
        < (1 - 6 * 0.010000)
      )
      and
      (
        apdex:ratio_30m{monitor="global",type="web"}
        < (1 - 6 * 0.010000)
      )
    |||,
  },

  testApdexBurnWithThreshold: {
    actual: expression.multiburnRateApdexExpression(
      aggregationSet=testAggregationSet,
      metricSelectorHash={ type: 'web' },
      thresholdSLOValue=0.9995,
    ),
    expect: |||
      (
        apdex:ratio_1h{monitor="global",type="web"}
        < (1 - 14.4 * 0.000500)
      )
      and
      (
        apdex:ratio_5m{monitor="global",type="web"}
        < (1 - 14.4 * 0.000500)
      )
      or
      (
        apdex:ratio_6h{monitor="global",type="web"}
        < (1 - 6 * 0.000500)
      )
      and
      (
        apdex:ratio_30m{monitor="global",type="web"}
        < (1 - 6 * 0.000500)
      )
    |||,
  },

  testApdexBurnWithMinimumSamples1h: {
    actual: expression.multiburnRateApdexExpression(
      aggregationSet=testAggregationSet,
      metricSelectorHash={ type: 'web' },
      thresholdSLOValue=0.99,
      windows=['1h'],
      requiredOpRate=0.01667,
      operationRateWindowDuration='1h',
    ),
    expect: |||
      (
        (
          apdex:ratio_1h{monitor="global",type="web"}
          < (1 - 14.4 * 0.010000)
        )
        and
        (
          apdex:ratio_5m{monitor="global",type="web"}
          < (1 - 14.4 * 0.010000)
        )
      )
      and on(environment,tier,type,stage)
      (
        sum by(environment,tier,type,stage) (operation:rate_1h{monitor="global",type="web"}) >= 0.01667
      )
    |||,
  },
})
