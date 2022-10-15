local durationParser = import './duration-parser.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  test1s: {
    actual: durationParser.toSeconds('1s'),
    expect: 1,
  },
  test2m: {
    actual: durationParser.toSeconds('2m'),
    expect: 60 * 2,
  },
  test3h: {
    actual: durationParser.toSeconds('3h'),
    expect: 3600 * 3,
  },
  test4d: {
    actual: durationParser.toSeconds('4d'),
    expect: 86400 * 4,
  },
  test5w: {
    actual: durationParser.toSeconds('5w'),
    expect: 86400 * 7 * 5,
  },
})
