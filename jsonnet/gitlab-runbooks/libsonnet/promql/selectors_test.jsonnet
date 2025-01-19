local selectors = import './selectors.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testSerializeHashNull: {
    actual: selectors.serializeHash(null),
    expect: '',
  },
  testSerializeHashEmpty: {
    actual: selectors.serializeHash({}),
    expect: '',
  },
  testSerializeHashSimple: {
    actual: selectors.serializeHash({ a: 'b' }),
    expect: 'a="b"',
  },
  testSerializeHashEq: {
    actual: selectors.serializeHash({ a: { eq: 'b' } }),
    expect: 'a="b"',
  },
  testSerializeHashNe: {
    actual: selectors.serializeHash({ a: { ne: 'b' } }),
    expect: 'a!="b"',
  },
  testSerializeHashRe: {
    actual: selectors.serializeHash({ a: { re: 'b' } }),
    expect: 'a=~"b"',
  },
  testSerializeHashNre: {
    actual: selectors.serializeHash({ a: { nre: 'b' } }),
    expect: 'a!~"b"',
  },
  testSerializeHashArray: {
    actual: selectors.serializeHash({ a: ['1', '2', '3'] }),
    expect: 'a="1",a="2",a="3"',
  },
  testSerializeHashEqArray: {
    actual: selectors.serializeHash({ a: { eq: ['1', '2', '3'] } }),
    expect: 'a="1",a="2",a="3"',
  },
  testSerializeHashNeArray: {
    actual: selectors.serializeHash({ a: { ne: ['1', '2', '3'] } }),
    expect: 'a!="1",a!="2",a!="3"',
  },
  testSerializeHashReArray: {
    actual: selectors.serializeHash({ a: { re: ['1', '2', '3'] } }),
    expect: 'a=~"1",a=~"2",a=~"3"',
  },
  testSerializeHashNreArray: {
    actual: selectors.serializeHash({ a: { nre: ['1', '2', '3'] } }),
    expect: 'a!~"1",a!~"2",a!~"3"',
  },
  testSerializeHashMixedArray: {
    actual: selectors.serializeHash({ a: [{ eq: '1' }, { ne: '2' }, { re: '3' }, { nre: '4' }] }),
    expect: 'a="1",a!="2",a=~"3",a!~"4"',
  },
  testSerializeHashOneOf: {
    actual: selectors.serializeHash({ a: { oneOf: [3, 'two', '1'] } }),
    expect: 'a=~"1|3|two"',
  },
  testSerializeHashDuplicate: {
    actual: selectors.serializeHash({ a: { oneOf: [1, '1'] } }),
    expect: 'a=~"1"',
  },
  testSerializeHashNoneOf: {
    actual: selectors.serializeHash({ a: { noneOf: [1, 'two', 3] } }),
    expect: 'a!~"1|3|two"',
  },
  testSerializeHashMultiple: {
    actual: selectors.serializeHash({ a: { re: '.*', ne: 'moo' } }),
    expect: 'a!="moo",a=~".*"',
  },
  testSerializeHashEmtpyWithBraces: {
    actual: selectors.serializeHash({}, withBraces=true),
    expect: '',
  },
  testSerializeHashSimpleWithBraces: {
    actual: selectors.serializeHash({ a: 1 }, withBraces=true),
    expect: '{a="1"}',
  },
  testMergeTwoNulls: {
    actual: selectors.merge(null, null),
    expect: null,
  },
  testMergeANull: {
    actual: selectors.merge(null, { b: 1 }),
    expect: { b: 1 },
  },
  testMergeBNull: {
    actual: selectors.merge({ a: 1 }, null),
    expect: { a: 1 },
  },
  testMergeStrings: {
    actual: selectors.merge('a="1"', 'b="2"'),
    expect: 'a="1", b="2"',
  },
  testMergeMixed1: {
    actual: selectors.merge('a="1"', { b: 2 }),
    expect: 'a="1", b="2"',
  },
  testMergeMixed2: {
    actual: selectors.merge({ a: 1 }, 'b="2"'),
    expect: 'a="1", b="2"',
  },
  testMergeHashes: {
    actual: selectors.merge({ a: 1 }, { b: '2' }),
    expect: { a: 1, b: '2' },
  },
  testWithout: {
    actual: selectors.without({ a: 1, b: 2 }, ['b']),
    expect: { a: 1 },
  },
  testWithoutEmptyArray: {
    actual: selectors.without({ a: 1, b: 2 }, []),
    expect: { a: 1, b: 2 },
  },
  testWithoutEmptyObject: {
    actual: selectors.without({}, ['c', 'd']),
    expect: {},
  },
  testWithoutNull: {
    actual: selectors.without(null, ['c', 'd']),
    expect: null,
  },
  testWithoutStringAndEmpty: {
    actual: selectors.without('some string', []),
    expect: 'some string',
  },
})
