local alerts = import 'alerts/alerts.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

local labels = {
  rules_domain: 'general',
  severity: 's4',
  alert_type: 'cause',
};

local rules = [
  // Ops Rate
  {
    alert: 'gitlab_component_opsrate_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_ops:rate{monitor!="global"} offset 1d >= 0
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_ops:rate{monitor!="global"} >= 0
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{monitor="global"}
    |||,
    'for': '1h',
    labels: labels,
    annotations: {
      title: 'Operation rate data for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_ops:rate` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_opsrate_missing/alerts-component-request-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
    },
  },
  {
    // Apdex
    alert: 'gitlab_component_apdex_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_apdex:ratio{monitor="global"} offset 1d >= 0
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_apdex:ratio{monitor="global"}
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{monitor="global"}
    |||,
    'for': '1h',
    labels: labels,
    annotations: {
      title: 'Apdex for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_apdex:ratio` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_opsrate_missing/alerts-component-request-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
    },
  },
  {
    // Error Rate
    // For error rate, ignore the `cny` stage, as without much traffic,
    // the likelihood of errors will be reduced, leading to
    // `gitlab_component_error_missing_series` alerts
    alert: 'gitlab_component_error_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          (gitlab_component_errors:rate{monitor!="global", stage!="cny"} offset 1d)
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_errors:rate{monitor!="global", stage!="cny"}
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{monitor="global"}
    |||,
    'for': '2h',
    labels: labels,
    annotations: {
      title: 'Error rate data for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_errors:rate` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_error_missing/alerts-component-error-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
    },
  },
];

{
  'missing-series-alerts.yml': std.manifestYamlDoc({
    groups: [
      {
        name: 'missing_series_alerts.rules',
        partial_response_strategy: 'warn',
        rules: alerts.processAlertRules(rules),
      },
    ],
  }),
}
