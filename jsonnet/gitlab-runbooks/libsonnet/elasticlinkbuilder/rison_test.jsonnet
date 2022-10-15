local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local rison = import 'rison.libsonnet';

test.suite({
  testBlank: {
    actual: rison.encode({}),
    expect: '()',
  },

  testString: {
    actual: rison.encode({ name: 'value' }),
    expect: '(name:value)',
  },

  testEmptyString: {
    actual: rison.encode({ name: '' }),
    expect: "(name:'')",
  },

  testStringWithQuotes: {
    actual: rison.encode(["foo 'bar' \"baz\""]),
    expect: "!('foo+!'bar!'+\"baz\"')",
  },

  testNumber: {
    actual: rison.encode({ name: 1 }),
    expect: '(name:1)',
  },

  testHash: {
    actual: rison.encode({ name: { first: 'A', last: 'Z' } }),
    expect: '(name:(first:A,last:Z))',
  },

  testArray: {
    actual: rison.encode({ name: [{ first: 'A' }] }),
    expect: '(name:!((first:A)))',
  },

  testUnsafeKey: {
    actual: rison.encode({ 'X 1': 5 }),
    expect: "('X+1':5)",
  },

  testUnsafeValue: {
    actual: rison.encode({ name: [{ first: 'A or B+3' }] }),
    expect: "(name:!((first:'A+or+B%2B3')))",
  },

})
