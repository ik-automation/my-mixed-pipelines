local objects = import './objects.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testFromPairs: {
    actual: objects.fromPairs([['a', 1], ['b', [2, 3]], ['c', { d: 4 }]]),
    expect: { a: 1, b: [2, 3], c: { d: 4 } },
  },
  testFromPairsIntegerKeys: {
    actual: objects.fromPairs([[1, 1], [2, [2, 3]], [3, { d: 4 }]]),
    expect: { '1': 1, '2': [2, 3], '3': { d: 4 } },
  },
  testFromPairsDuplicateKeys: {
    actual: objects.fromPairs([[1, 1], [2, [2, 3]], [1, { d: 4 }]]),
    expect: { '1': 1, '2': [2, 3] },
  },
  testObjectWithout: {
    actual: objects.objectWithout({ hello: 'world', foo: 'bar', baz:: 'hi' }, 'foo'),
    expect: { hello: 'world', baz:: 'hi' },
  },
  testObjectWithoutIncHiddenFunction: {
    local testThing = { hello(world):: [world] },
    actual: objects.objectWithout(testThing { foo: 'bar' }, 'foo').hello('world'),
    expect: ['world'],
  },
  testFromPairsRoundTrip: {
    actual: objects.fromPairs(objects.toPairs({ '1': 1, '2': [2, 3], '3': { d: 4 } })),
    expect: { '1': 1, '2': [2, 3], '3': { d: 4 } },
  },
  testToPairs: {
    actual: objects.toPairs({ a: 1, b: [2, 3], c: { d: 4 } }),
    expect: [['a', 1], ['b', [2, 3]], ['c', { d: 4 }]],
  },
  testToPairsRoundTrip: {
    actual: objects.toPairs(objects.fromPairs([['a', 1], ['b', [2, 3]], ['c', { d: 4 }]])),
    expect: [['a', 1], ['b', [2, 3]], ['c', { d: 4 }]],
  },
  testMergeAllTrivial: {
    actual: objects.mergeAll([]),
    expect: {},
  },
  testMergeAllWithoutClashes: {
    actual: objects.mergeAll([{ a: 1 }, { b: 'b' }, { c: { d: 1 } }]),
    expect: {
      a: 1,
      b: 'b',
      c: { d: 1 },
    },
  },
  testMergeAllWithClashes: {
    actual: objects.mergeAll([{ a: { a: 1, d: 1 } }, { a: { c: 1, d: 2 } }]),
    expect: {
      a: { c: 1, d: 2 },
    },
  },

  testMapKeyValues: {
    actual: objects.mapKeyValues(function(key, value) [key + 'a', value + 1], { a: 1, b: 2, c: 3 }),
    expect: {
      aa: 2,
      ba: 3,
      ca: 4,
    },
  },

  testMapKeyValuesOmit: {
    actual: objects.mapKeyValues(function(key, value) null, { a: 1, b: 2, c: 3 }),
    expect: {},
  },

})
