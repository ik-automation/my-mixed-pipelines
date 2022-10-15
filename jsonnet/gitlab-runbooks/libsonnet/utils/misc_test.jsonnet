local misc = import './misc.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testAllFalse: {
    actual: misc.all(function(num) num % 2 == 0, [0, 1, 2, 3]),
    expect: false,
  },
  testAllTrue: {
    actual: misc.all(function(num) num % 2 == 0, [0, 2, 4, 6]),
    expect: true,
  },
  testAllEmpty: {
    actual: misc.all(function(num) num % 2 == 0, []),
    expect: true,
  },
  testAnyFalse: {
    actual: misc.any(function(num) num % 2 == 0, [1, 3, 5, 7, 9]),
    expect: false,
  },
  testAnyTrue: {
    actual: misc.any(function(num) num % 2 == 0, [0, 1, 3, 5, 7]),
    expect: true,
  },
  testAnyEmpty: {
    actual: misc.any(function(num) num % 2 == 0, []),
    expect: false,
  },
  testIsPresentNull: {
    actual: misc.isPresent(null),
    expect: false,
  },
  testIsPresentNullValue: {
    actual: misc.isPresent(null, 'null_value'),
    expect: 'null_value',
  },
  testIsPresentObject: {
    actual: misc.isPresent({ a: 1 }),
    expect: true,
  },
  testIsPresentObjectEmpty: {
    actual: misc.isPresent({}),
    expect: false,
  },
  testIsPresentArray: {
    actual: misc.isPresent([1, 3, 4]),
    expect: true,
  },
  testIsPresentArrayEmpty: {
    actual: misc.isPresent([]),
    expect: false,
  },
  testIsPresentTrue: {
    actual: misc.isPresent(true),
    expect: true,
  },
  testIsPresentFalse: {
    actual: misc.isPresent(false),
    expect: false,
  },
  testDigLEmpty: {
    actual: misc.dig({}, ['a']),
    expect: {},
  },
  testDigLShallow: {
    actual: misc.dig({ a: 1, b: 2 }, ['a']),
    expect: 1,
  },
  testDigMiddle: {
    actual: misc.dig({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b']),
    expect: { c: 3 },
  },
  testDigDeep: {
    actual: misc.dig({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b', 'c']),
    expect: 3,
  },
  testDigNotExistLeaf: {
    actual: misc.dig({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b', 'd']),
    expect: {},
  },
  testDigNotExistMiddle: {
    actual: misc.dig({ a: { b: { c: 3 } }, d: 2 }, ['a', 'c', 'c']),
    expect: {},
  },
  testDigNotExistTop: {
    actual: misc.dig({ a: { b: { c: 3 } }, d: 2 }, ['b', 'b', 'c']),
    expect: {},
  },
  testDigHasLEmpty: {
    actual: misc.digHas({}, ['a']),
    expect: false,
  },
  testDigHasLShallow: {
    actual: misc.digHas({ a: 1, b: 2 }, ['a']),
    expect: true,
  },
  testDigHasMiddle: {
    actual: misc.digHas({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b']),
    expect: true,
  },
  testDigHasDeep: {
    actual: misc.digHas({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b', 'c']),
    expect: true,
  },
  testDigHasNotExistLeaf: {
    actual: misc.digHas({ a: { b: { c: 3 } }, d: 2 }, ['a', 'b', 'd']),
    expect: false,
  },
  testDigHasNotExistMiddle: {
    actual: misc.digHas({ a: { b: { c: 3 } }, d: 2 }, ['a', 'c', 'c']),
    expect: false,
  },
  testDigHasNotExistTop: {
    actual: misc.digHas({ a: { b: { c: 3 } }, d: 2 }, ['b', 'b', 'c']),
    expect: false,
  },
  testArrayDiff: {
    actual: misc.arrayDiff(['a', 'b', 'c', 'd'], ['b', 'c', 'e']),
    expect: ['a', 'd'],
  },
  testArrayDiffDuplicated: {
    actual: misc.arrayDiff(['a', 'a', 'b', 'c', 'c', 'c', 'd'], ['b', 'c', 'e']),
    expect: ['a', 'a', 'c', 'c', 'd'],
  },
  testArrayDiffEmptyArrayLeft: {
    actual: misc.arrayDiff([], ['b', 'c', 'e']),
    expect: [],
  },
  testArrayDiffEmptyArrayRight: {
    actual: misc.arrayDiff(['a', 'b', 'c'], []),
    expect: ['a', 'b', 'c'],
  },
  testObjectIncludes: {
    actual: misc.objectIncludes({ a: 'a', b: 2 }, { b: 2 }),
    expect: true,
  },
  testObjectIncludesFalse: {
    actual: misc.objectIncludes({ a: 'a', b: 2 }, { b: 1 }),
    expect: false,
  },

  testObjectIncludesMultiple: {
    actual: misc.objectIncludes({ a: 'a', b: 1, c: 'b' }, { c: 'b', b: 1 }),
    expect: true,
  },

})
