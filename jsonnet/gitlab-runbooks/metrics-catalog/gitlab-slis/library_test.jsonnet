local library = import './library.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testGet: {
    actual: library.get('rails_request').apdexSuccessCounterName,
    expect: 'gitlab_sli_rails_request_apdex_success_total',
  },
  testAll: {
    actual: std.map(function(sli) sli.name, library.all),
    expectThat: {
      actual: error 'overridden',
      result: std.member(self.actual, 'rails_request'),
    },
  },
})
