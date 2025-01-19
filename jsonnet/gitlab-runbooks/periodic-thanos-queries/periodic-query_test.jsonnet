local periodicQueries = import './periodic-query.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testDefaults: {
    actual: periodicQueries.new({
      query: 'promql',
    }),
    expect: {
      query: 'promql',
      type: 'instant',
    },
  },
})
