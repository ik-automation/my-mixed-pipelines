local aggregations = import './aggregations.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testJoin: {
    actual: aggregations.join(['b', 'c', 'd', 'b', 'a', 'b', 'c']),
    expect: 'a,b,c,d',
  },
})
