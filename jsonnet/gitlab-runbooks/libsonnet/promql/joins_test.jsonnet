local joins = import './joins.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local expressions = [
  'up > 0',
  'down < 1',
];

test.suite({
  testEmptyJoin: {
    actual: joins.join('and', [], wrapTerms=true),
    expect: '',
  },
  testAndJoin: {
    actual: joins.join('and', expressions, wrapTerms=true),
    expect: |||
      (
        up > 0
      )
      and
      (
        down < 1
      )
    |||,
  },
  testOrJoin: {
    actual: joins.join('or', expressions, wrapTerms=false),
    expect: |||
      up > 0
      or
      down < 1
    |||,
  },
  testMultiplyJoin: {
    actual: joins.join('*', expressions, wrapTerms=false),
    expect: |||
      up > 0
      *
      down < 1
    |||,
  },

})
