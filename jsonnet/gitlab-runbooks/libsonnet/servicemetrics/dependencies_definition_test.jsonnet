local dependencies = import './dependencies_definition.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testGenerateInhibitionRules: {
    actual: dependencies.new(
      'web',
      'workhorse',
      [
        {
          component: 'rails_primary_sql',
          type: 'patroni',
        },
        {
          component: 'rails_replica_sql',
          type: 'patroni',
        },
      ]
    ).generateInhibitionRules(),
    expect: [
      {
        equal: ['env', 'environment', 'pager'],
        source_matchers: ['component="rails_primary_sql"', 'type="patroni"'],
        target_matchers: ['component="workhorse"', 'type="web"'],
      },
      {
        equal: ['env', 'environment', 'pager'],
        source_matchers: ['component="rails_replica_sql"', 'type="patroni"'],
        target_matchers: ['component="workhorse"', 'type="web"'],
      },
    ],
  },
})
