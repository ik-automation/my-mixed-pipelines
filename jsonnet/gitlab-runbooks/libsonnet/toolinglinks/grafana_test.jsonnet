local grafana = import './grafana.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testGrafanaUid: {
    actual: std.map(
      function(path) grafana.grafanaUid(path), [
        'product/plan.jsonnet',
        'product/plan.error_budget.jsonnet',
        'product/plan-error-budget.jsonnet',
        'stage-groups/access.dashboard.jsonnet',
        'stage-groups/code_review.dashboard.jsonnet',
      ]
    ),
    expect: [
      'product-plan',
      'product-plan',
      'product-plan-error-budget',
      'stage-groups-access',
      'stage-groups-code_review',
    ],
  },
  testGenerateMarkdownBlank: {
    actual: grafana.grafana('Dash', 'dash', vars={ moo: 'cow', bat: 'ozzy' })(options={}),
    expect: [{
      title: 'Grafana: Dash',
      url: '/d/dash?var-bat=ozzy&var-moo=cow',
    }],
  },
})
