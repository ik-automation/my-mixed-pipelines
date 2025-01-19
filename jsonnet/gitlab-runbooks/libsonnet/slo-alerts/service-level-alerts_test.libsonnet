local serviceLevelAlerts = import './service-level-alerts.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local test = import 'test.libsonnet';
local strings = import 'utils/strings.libsonnet';

local testAggregationSet = aggregationSet.AggregationSet({
  id: 'test',
  name: 'Test',
  intermediateSource: false,
  selector: { monitor: 'global' },  // Not Thanos Ruler
  labels: ['environment', 'tier', 'type', 'stage'],
  burnRates: {
    '5m': {
      apdexRatio: 'apdex:ratio_5m',
      apdexWeight: 'apdex:weight:score_5m',
      opsRate: 'operation:rate_5m',
      errorRate: 'error:rate_5m',
      errorRatio: 'error:ratio_5m',
    },
    '30m': {
      apdexRatio: 'apdex:ratio_30m',
      apdexWeight: 'apdex:weight:score_30m',
      opsRate: 'operation:rate_30m',
      errorRate: 'error:rate_30m',
      errorRatio: 'error:ratio_30m',
    },
    '1h': {
      apdexRatio: 'apdex:ratio_1h',
      apdexWeight: 'apdex:weight:score_1h',
      opsRate: 'operation:rate_1h',
      errorRate: 'error:rate_1h',
      errorRatio: 'error:ratio_1h',
    },
    '6h': {
      apdexRatio: 'apdex:ratio_6h',
      apdexWeight: 'apdex:weight:score_6h',
      opsRate: 'operation:rate_6h',
      errorRate: 'error:rate_6h',
      errorRatio: 'error:ratio_6h',
    },
    '3d': {
      apdexRatio: 'apdex:ratio_3d',
      apdexWeight: 'apdex:weight:score_3d',
      opsRate: 'operation:rate_3d',
      errorRate: 'error:rate_3d',
      errorRatio: 'error:ratio_3d',
    },
  },
});


test.suite({
  testErrorAlertsForSLIDefaults: {
    actual: serviceLevelAlerts.errorAlertsForSLI(
      'errors',
      'errorTitle',
      ['there are too many errors'],
      'api',
      's2',
      0.999,
      testAggregationSet,
      ['1h', '6h'],
      {}
    ),
    expect: [
      {
        alert: 'errors',
        annotations: {
          description: |||
            there are too many errors

            Currently the error-rate is {{ $value | humanizePercentage }}.
          |||,
          grafana_dashboard_id: 'alerts-test_slo_error',
          grafana_min_zoom_hours: '6',
          grafana_panel_id: 965700560,
          grafana_variables: 'environment,type,stage',
          runbook: 'docs/api/README.md',
          title: 'errorTitle',
        },
        expr: |||
          (
            error:ratio_1h{monitor="global"}
            > (14.4 * 0.001000)
          )
          and
          (
            error:ratio_5m{monitor="global"}
            > (14.4 * 0.001000)
          )
        |||,
        'for': '2m',
        labels: {
          aggregation: 'test',
          alert_class: 'slo_violation',
          alert_type: 'symptom',
          pager: 'pagerduty',
          rules_domain: 'general',
          severity: 's2',
          sli_type: 'error',
          slo_alert: 'yes',
          window: '1h',
        },
      },
      {
        alert: 'errors',
        annotations: {
          description: |||
            there are too many errors

            Currently the error-rate is {{ $value | humanizePercentage }}.
          |||,
          grafana_dashboard_id: 'alerts-test_slo_error',
          grafana_min_zoom_hours: '6',
          grafana_panel_id: 965700560,
          grafana_variables: 'environment,type,stage',
          runbook: 'docs/api/README.md',
          title: 'errorTitle',
        },
        expr: |||
          (
            error:ratio_6h{monitor="global"}
            > (6 * 0.001000)
          )
          and
          (
            error:ratio_30m{monitor="global"}
            > (6 * 0.001000)
          )
        |||,
        'for': '2m',
        labels: {
          aggregation: 'test',
          alert_class: 'slo_violation',
          alert_type: 'symptom',
          pager: 'pagerduty',
          rules_domain: 'general',
          severity: 's2',
          sli_type: 'error',
          slo_alert: 'yes',
          window: '6h',
        },
      },
    ],
  },
  testErrorAlertsForSLIMinimumSamples: {
    actual: std.map(function(alert) alert.expr, serviceLevelAlerts.errorAlertsForSLI(
      'errors',
      'errorTitle',
      ['there are too many errors'],
      'api',
      's2',
      0.999,
      testAggregationSet,
      ['1h', '6h'],
      {},
      minimumSamplesForMonitoring=3600
    )),
    expect: [
      |||
        (
          (
            error:ratio_1h{monitor="global"}
            > (14.4 * 0.001000)
          )
          and
          (
            error:ratio_5m{monitor="global"}
            > (14.4 * 0.001000)
          )
        )
        and on(environment,tier,type,stage)
        (
          sum by(environment,tier,type,stage) (operation:rate_1h{monitor="global"}) >= 1
        )
      |||,
      |||
        (
          (
            error:ratio_6h{monitor="global"}
            > (6 * 0.001000)
          )
          and
          (
            error:ratio_30m{monitor="global"}
            > (6 * 0.001000)
          )
        )
        and on(environment,tier,type,stage)
        (
          sum by(environment,tier,type,stage) (operation:rate_6h{monitor="global"}) >= 0.16667
        )
      |||,
    ],
  },
})
