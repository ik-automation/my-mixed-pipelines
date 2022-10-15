local gaugeMetric = import './gauge_metric.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testaggregatedRateQuery1: {
    actual: gaugeMetric.gaugeMetric(gauge='x').aggregatedRateQuery(['a', 'b', 'c'], null, '7m'),
    expect: |||
      sum by (a,b,c) (
        avg_over_time(x{}[7m])
      )
    |||,
  },

  testaggregatedRateQuery2: {
    actual: gaugeMetric.gaugeMetric(gauge='x', selector={ a: 1 }).aggregatedRateQuery(['a', 'b', 'c'], null, '7m'),
    expect: |||
      sum by (a,b,c) (
        avg_over_time(x{a="1"}[7m])
      )
    |||,
  },

  testaggregatedRateQuery3: {
    actual: gaugeMetric.gaugeMetric(gauge='x', selector={ a: 1 }).aggregatedRateQuery(['a', 'b', 'c'], { b: 2 }, '7m'),
    expect: |||
      sum by (a,b,c) (
        avg_over_time(x{a="1",b="2"}[7m])
      )
    |||,
  },

})
