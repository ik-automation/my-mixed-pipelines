local alerts = import 'alerts/alerts.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

local rules = [
  //###############################################
  // Operation Rate: how many operations is this service handling per second?
  //###############################################
  // ------------------------------------
  // Upper bound thresholds exceeded
  // ------------------------------------
  // Warn: Operation rate above 2 sigma
  {
    alert: 'service_ops_out_of_bounds_upper_5m',
    expr: |||
      (
          (
            (gitlab_service_ops:rate{monitor="global"} -  gitlab_service_ops:rate:prediction{monitor="global"}) /
          gitlab_service_ops:rate:stddev_over_time_1w{monitor="global"}
        )
        >
        3
      )
      unless on(tier, type)
      gitlab_service:mapping:disable_ops_rate_prediction{monitor="global"}
    |||,
    'for': '5m',
    labels: {
      rules_domain: 'general',
      severity: 's4',
      alert_type: 'cause',
    },
    annotations: {
      description: |||
        The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving more requests than normal.
        This is often caused by user generated traffic, sometimes abuse. It can also be cause by application changes that lead to higher operations rates or from retries in the event of errors. Check the abuse reporting watches in Elastic, ELK for possible abuse, error rates (possibly on upstream services) for root cause.
      |||,
      runbook: 'docs/{{ $labels.type }}/README.md',
      title: 'Anomaly detection: The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving more requests than normal',
      grafana_dashboard_id: 'general-service/service-platform-metrics',
      grafana_panel_id: stableIds.hashStableId('service-$type-ops-rate'),
      grafana_variables: 'environment,type,stage',
      grafana_min_zoom_hours: '12',
      link1_title: 'Definition',
      link1_url: 'https://gitlab.com/gitlab-com/runbooks/blob/master/docs/monitoring/definition-service-ops-rate.md',
      promql_template_1: 'gitlab_service_ops:rate{environment="$environment", type="$type", stage="$stage"}',
      promql_template_2: 'gitlab_component_ops:rate{environment="$environment", type="$type", stage="$stage"}',
    },
  },
  // ------------------------------------
  // Lower bound thresholds exceeded
  // ------------------------------------
  // Warn: Operation rate below 2 sigma
  {
    alert: 'service_ops_out_of_bounds_lower_5m',
    expr: |||
      (
          (
            (gitlab_service_ops:rate{monitor="global"} -  gitlab_service_ops:rate:prediction{monitor="global"}) /
          gitlab_service_ops:rate:stddev_over_time_1w{monitor="global"}
        )
        <
        -3
      )
      unless on(tier, type)
      gitlab_service:mapping:disable_ops_rate_prediction{monitor="global"}
    |||,
    'for': '5m',
    labels: {
      rules_domain: 'general',
      severity: 's4',
      alert_type: 'cause',
    },
    annotations: {
      description: |||
        The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving fewer requests than normal.
        This is often caused by a failure in an upstream service - for example, an upstream load balancer rejected all incoming traffic. In many cases, this is as serious or more serious than a traffic spike. Check upstream services for errors that may be leading to traffic flow issues in downstream services.
      |||,
      runbook: 'docs/{{ $labels.type }}/README.md',
      title: 'Anomaly detection: The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving fewer requests than normal',
      grafana_dashboard_id: 'general-service/service-platform-metrics',
      grafana_panel_id: stableIds.hashStableId('service-$type-ops-rate'),
      grafana_variables: 'environment,type,stage',
      grafana_min_zoom_hours: '12',
      link1_title: 'Definition',
      link1_url: 'https://gitlab.com/gitlab-com/runbooks/blob/master/docs/monitoring/definition-service-ops-rate.md',
      promql_template_1: 'gitlab_service_ops:rate{environment="$environment", type="$type", stage="$stage"}',
      promql_template_2: 'gitlab_component_ops:rate{environment="$environment", type="$type", stage="$stage"}',
    },
  },

  //###############################################
  // Bad canary: we are experiencing errors or latency issues in
  // canary, but not in production. This probably indicates that
  // we have a dud canary
  //
  // When traffic volume to the canary is below 1% of the
  // traffic to the main production stage, the bad-canary
  // alerts will not fire. This avoids low-traffic
  // random noise alerts.
  //
  //###############################################
  // DEPRECATED in favour of multiwindow, multiburn-rate alerts
  {
    alert: 'service_cny_apdex_slo_out_of_bounds_lower_5m',
    expr: |||
      (
          (
            (
              avg(gitlab_service_apdex:ratio{stage="cny", monitor="global"}) by (environment, tier, type)
            < ignoring(environment, stage) group_left
              avg(slo:min:gitlab_service_apdex:ratio{monitor="global"}) by (tier, type)
          )
          unless ignoring(stage)
          (
              avg(gitlab_service_apdex:ratio{stage="main", monitor="global"}) by (environment, tier, type)
            < ignoring(environment, stage) group_left
              avg(slo:min:gitlab_service_apdex:ratio{monitor="global"}) by (tier, type)
          )
        )
        and on(environment, tier, type)
        (
            (
              gitlab_service_ops:rate{stage="cny", monitor="global"}
            / ignoring(stage)
            gitlab_service_ops:rate{stage="main", monitor="global"}
          ) >= 0.01
        )
      )
      unless on(tier, type)
      (
          slo:min:events:gitlab_service_apdex:ratio{monitor="global"}
      )
    |||,
    'for': '5m',
    labels: {
      rules_domain: 'general',
      canary_warning: 'yes',
      severity: 's2',
      slo_alert: 'yes',
      pager: 'pagerduty',
      alert_type: 'symptom',
      deprecated: 'yes',
    },
    annotations: {
      description: |||
        The `cny` stage of  the `{{ $labels.type }}` service has a apdex score (latency) below SLO, but the main stage does not.
        While there are other reasons, such as high traffic to the canary stage, experiencing a high error rate in `cny`, without any corresponding errors in `main` stage could indicate a malfunctioning canary deploy.
        Consider investigating further. If there is no evidence of another cause, please consider stopping the deployment process while the problem is investigated.
        This could indicate that the canary deployment is not functioning correctly. Please consider stopping the deployment process while the problem is investigated.
      |||,
      runbook: 'docs/{{ $labels.type }}/README.md',
      title: 'Bad canary? The `cny` stage of  the `{{ $labels.type }}` service has a apdex score (latency) below SLO, but the main stage does not.',
      grafana_dashboard_id: 'general-service-stages/general-service-platform-metrics-stages',
      grafana_panel_id: stableIds.hashStableId('apdex-ratio'),
      grafana_variables: 'environment,type',
      grafana_min_zoom_hours: '6',
      link1_title: 'Definition',
      link1_url: 'https://gitlab.com/gitlab-com/runbooks/blob/master/docs/monitoring/definition-service-apdex.md',
      promql_template_1: 'gitlab_service_apdex:ratio{environment="$environment", type="$type", stage="$stage"}',
      promql_template_2: 'gitlab_component_apdex:ratio{environment="$environment", type="$type", stage="$stage"}',
    },
  },
  {
    alert: 'service_cny_error_ratio_slo_out_of_bounds_upper_5m',
    expr: |||
      (
          (
            (
              avg(gitlab_service_errors:ratio{stage="cny", monitor="global"}) by (environment, tier, type, stage)
            > ignoring(environment, stage) group_left
            avg(slo:max:gitlab_service_errors:ratio{monitor="global"}) by (tier, type)
          )
          unless ignoring(stage)
          (
              avg(gitlab_service_errors:ratio{stage="main", monitor="global"}) by (environment, tier, type, stage)
            > ignoring(environment, stage) group_left
            avg(slo:max:gitlab_service_errors:ratio{monitor="global"}) by (tier, type)
          )
        )
        and on(environment, tier, type)
        (
            (
              gitlab_service_ops:rate{stage="cny", monitor="global"}
            / ignoring(stage)
            gitlab_service_ops:rate{stage="main", monitor="global"}
          ) >= 0.01
        )
      )
      unless on(tier, type)
      (
          slo:max:events:gitlab_service_errors:ratio{monitor="global"}
      )
    |||,
    'for': '5m',
    labels: {
      rules_domain: 'general',
      canary_warning: 'yes',
      severity: 's2',
      slo_alert: 'yes',
      pager: 'pagerduty',
      alert_type: 'symptom',
      deprecated: 'yes',
    },
    annotations: {
      description: |||
        The `cny` stage of  the `{{ $labels.type }}` service has an error-ratio exceeding SLO, but the main stage does not.
        While there are other reasons, such as high traffic to the canary stage, experiencing a high error rate in `cny`, without any corresponding errors in `main` stage could indicate a malfunctioning canary deploy.
        Consider investigating further. If there is no evidence of another cause, please consider stopping the deployment process while the problem is investigated.
      |||,
      runbook: 'docs/{{ $labels.type }}/README.md',
      title: 'Bad canary? The `cny` stage of  the `{{ $labels.type }}` service has an error-ratio exceeding SLO, but the main stage does not.',
      grafana_dashboard_id: 'general-service-stages/general-service-platform-metrics-stages',
      grafana_panel_id: stableIds.hashStableId('error-ratio'),
      grafana_variables: 'environment,type',
      grafana_min_zoom_hours: '6',
      link1_title: 'Definition',
      link1_url: 'https://gitlab.com/gitlab-com/runbooks/blob/master/docs/monitoring/definition-service-error-rate.md',
      promql_template_1: 'gitlab_service_errors:ratio{environment="$environment", type="$type", stage="$stage"}',
      promql_template_2: 'gitlab_component_errors:ratio{environment="$environment", type="$type", stage="$stage"}',
    },
  },
];


{
  'service-alerts.yml': std.manifestYamlDoc({
    groups: [
      {
        name: 'slo_alerts.rules',
        partial_response_strategy: 'warn',
        rules: alerts.processAlertRules(rules),
      },
    ],
  }),
}
