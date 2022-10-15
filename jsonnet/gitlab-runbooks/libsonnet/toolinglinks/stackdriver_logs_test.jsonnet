local stackdriverLogs = import './stackdriver_logs.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local strings = import 'utils/strings.libsonnet';

test.suite({
  testToolingLink: {
    actual: stackdriverLogs.stackdriverLogsEntry(
      title='simple',
      queryHash={ a: 'b', c: 1 },
    )(options={}),
    expect: {
      title: 'simple',
      url: 'https://console.cloud.google.com/logs/query;query=a%3D%22b%22%0Ac%3D1;timeRange=PT30M?project=gitlab-production',
    },
  },
  testSerializeEmptyHashes: {
    actual: stackdriverLogs.serializeQueryHash({}),
    expect: '',
  },
  testSerializeGreaterThanLessThanOperators: {
    actual: stackdriverLogs.serializeQueryHash({
      a: { lt: 1 },
      b: { gt: 2 },
      c: { gte: 3 },
      d: { lte: 5 },
      e: { ne: '6' },
    }),
    expect: strings.chomp(|||
      a<1
      b>2
      c>=3
      d<=5
      -e="6"
    |||),
  },
  testArrays1: {
    actual: stackdriverLogs.serializeQueryHash({
      a: { ne: ['1', '2', '3'] },
    }),
    expect: strings.chomp(|||
      -a="1"
      -a="2"
      -a="3"
    |||),
  },
  testArrays2: {
    actual: stackdriverLogs.serializeQueryHash({
      a: [{ gt: 1 }, { lt: 2 }],
      b: [{ gt: 3 }, { lt: 4 }],
    }),
    expect: strings.chomp(|||
      a>1
      a<2
      b>3
      b<4
    |||),
  },
  testOneOf: {
    actual: stackdriverLogs.serializeQueryHash({
      a: { one_of: ['a', 'b', 'c'] },
      b: { one_of: ['1', '2', '3'] },
    }),
    expect: strings.chomp(|||
      a=("a" OR "b" OR "c")
      b=("1" OR "2" OR "3")
    |||),
  },
  testContains: {
    actual: stackdriverLogs.serializeQueryHash({
      a: { contains: ['sheep'] },
    }),
    expect: strings.chomp(|||
      a:"sheep"
    |||),
  },
  testExists: {
    actual: stackdriverLogs.serializeQueryHash({
      a: { exists: true },
      b: { exists: false },
    }),
    expect: strings.chomp(|||
      a:*
      -b:*
    |||),
  },
})
