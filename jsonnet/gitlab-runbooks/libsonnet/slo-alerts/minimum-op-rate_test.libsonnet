local minimumOpRate = import './minimum-op-rate.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  test1h: {
    expect: 1,
    actual: minimumOpRate.calculateFromSamplesForDuration('1h', 3600),
  },

  testNull: {
    expect: null,
    actual: minimumOpRate.calculateFromSamplesForDuration('1h', null),
  },
})
