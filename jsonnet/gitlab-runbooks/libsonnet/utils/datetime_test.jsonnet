local datetime = import './datetime.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local aDateTime = datetime.new('2021-10-27T10:13:40+02:00');
local utcDateTime = datetime.new('2021-10-27T10:11:40Z');

test.suite({
  testDate: {
    actual: aDateTime.date,
    expect: '2021-10-27',
  },
  testTimezone: {
    actual: aDateTime.timezone,
    expect: '+02:00',
  },
  testUtcTimezone: {
    actual: utcDateTime.timezone,
    expect: 'Z',
  },
  testBeginningOfDay: {
    actual: aDateTime.beginningOfDay.toString,
    expect: '2021-10-27T00:00:00+02:00',
  },
})
