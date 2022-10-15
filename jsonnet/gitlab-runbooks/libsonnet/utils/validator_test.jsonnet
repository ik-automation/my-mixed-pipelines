local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local validator = import 'validator.libsonnet';

local v1 = validator.new({
  stringValue: validator.string,
});

local v1Valid = {
  stringValue: 'name',
};

local v2 = validator.new({
  stringOrNumber: validator.or(validator.string, validator.number),
});

local v3 = validator.new({
  nested: {
    stringValue: validator.string,
    numberValue: validator.number,
  },
});

local matches = validator.validator(function(v) v == 'foo', 'does not match "foo"');

local v4 = validator.new({
  stringAndMatches: validator.and(validator.string, matches),
});

test.suite({
  testV1Basic: {
    actual: v1.assertValid(v1Valid),
    expect: v1Valid,
  },
  testV1BasicInvalidMissing: {
    actual: v1.isValid({ notName: 'name' }),
    expect: false,
  },
  testV1BasicInvalidWrongType: {
    actual: v1.isValid({ stringValue: 1 }),
    expect: false,
  },
  testV1BasicInvalidWrongTypeMessages: {
    actual: v1._validationMessages({ stringValue: 1 }),
    expect: ['field stringValue: expected a string'],
  },

  testV2Missing: {
    actual: v2._validationMessages({}),
    expect: ['field stringOrNumber is required'],
  },
  testV2String: {
    actual: v2.isValid({ stringOrNumber: '1' }),
    expect: true,
  },
  testV2Number: {
    actual: v2.isValid({ stringOrNumber: 1 }),
    expect: true,
  },
  testV2Invalid: {
    actual: v2._validationMessages({ stringOrNumber: true }),
    expect: ['field stringOrNumber: expected a string or expected a number'],
  },

  testV3Missing: {
    actual: v3._validationMessages({}),
    expect: ['field nested is required'],
  },
  testV3Valid: {
    actual: v3.isValid({ nested: { stringValue: 'a', numberValue: 1 } }),
    expect: true,
  },
  testV3Null: {
    actual: v3._validationMessages({ nested: null }),
    expect: ['field nested: expected an object'],
  },

  testV4Missing: {
    actual: v4._validationMessages({}),
    expect: ['field stringAndMatches is required'],
  },
  testV4Valid: {
    actual: v4.isValid({ stringAndMatches: 'foo' }),
    expect: true,
  },
  testV4InvalidFirst: {
    actual: v4._validationMessages({ stringAndMatches: true }),
    expect: ['field stringAndMatches: expected a string'],
  },
  testV4InvalidSecond: {
    actual: v4._validationMessages({ stringAndMatches: 'bar' }),
    expect: ['field stringAndMatches: does not match "foo"'],
  },
})
