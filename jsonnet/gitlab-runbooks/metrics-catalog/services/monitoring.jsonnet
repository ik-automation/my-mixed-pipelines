local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local gaugeMetric = metricsCatalog.gaugeMetric;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'monitoring',
  tier: 'inf',

  tags: ['cloud-sql', 'golang', 'grafana', 'prometheus', 'thanos'],

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  /*
   * Our anomaly detection uses normal distributions and the monitoring service
   * is prone to spikes that lead to a non-normal distribution. For that reason,
   * disable ops-rate anomaly detection on this service.
   */
  disableOpsRatePrediction: true,
  provisioning: {
    kubernetes: true,
    vms: true,
  },
  serviceDependencies: {
    'cloud-sql': true,
  },
  kubeResources: {
    grafana: {
      kind: 'Deployment',
      containers: [
        'grafana',
      ],
    },
    'grafana-image-renderer': {
      kind: 'Deployment',
      containers: [
        'grafana-image-renderer',
      ],
    },
    'thanos-query': {
      kind: 'Deployment',
      containers: [
        'thanos-query',
      ],
    },
    'thanos-query-frontend': {
      kind: 'Deployment',
      containers: [
        'thanos-query-frontend',
      ],
    },
    'thanos-store': {
      kind: 'StatefulSet',
      containers: [
        'thanos-store',
      ],
    },
    'memcached-thanos-qfe-query-range': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'memcached-thanos-qfe-labels': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'memcached-thanos-bucket-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'memcached-thanos-index-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
  },
  serviceLevelIndicators: {
    thanos_query: {
      monitoringThresholds: {
        apdexScore: 0.95,
        errorRatio: 0.95,
      },
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        Thanos query gathers the data needed to evaluate Prometheus queries from multiple underlying prometheus and thanos instances.
        This SLI monitors the Thanos query HTTP interface. 5xx responses are considered failures.
      |||,

      local thanosQuerySelector = {
        job: 'thanos-query',
        type: 'monitoring',
        shard: 'default',
      },

      apdex: histogramApdex(
        histogram='http_request_duration_seconds_bucket',
        selector=thanosQuerySelector,
        satisfiedThreshold=30,
        metricsFormat='openmetrics'
      ),

      requestRate: rateMetric(
        counter='http_requests_total',
        selector=thanosQuerySelector
      ),

      errorRate: rateMetric(
        counter='http_requests_total',
        selector=thanosQuerySelector { code: { re: '^5.*' } }
      ),

      significantLabels: ['pod'],
    },

    thanos_query_frontend: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        Thanos query gathers the data needed to evaluate Prometheus queries from multiple underlying prometheus and thanos instances.
        This SLI monitors the Thanos query HTTP interface. 5xx responses are considered failures.
      |||,

      local thanosQuerySelector = {
        job: 'thanos-query-frontend',
        type: 'monitoring',
        shard: 'default',
      },

      apdex: histogramApdex(
        histogram='http_request_duration_seconds_bucket',
        selector=thanosQuerySelector,
        satisfiedThreshold=30,
        metricsFormat='openmetrics'
      ),

      requestRate: rateMetric(
        counter='http_requests_total',
        selector=thanosQuerySelector
      ),

      errorRate: rateMetric(
        counter='http_requests_total',
        selector=thanosQuerySelector { code: { re: '^5.*' } }
      ),

      significantLabels: ['pod'],

      toolingLinks: [
        toolingLinks.kibana(title='Thanos Query', index='monitoring_ops', tag='monitoring.systemd.thanos-query'),
      ],
    },

    thanos_store: {
      monitoringThresholds: {
        apdexScore: 0.95,
        errorRatio: 0.95,
      },
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        Thanos store will respond to Thanos Query (and other) requests for historical data. This historical data is kept in
        GCS buckets. This SLI monitors the Thanos StoreAPI GRPC endpoint. GRPC error responses are considered to be service-level failures.
      |||,

      local thanosStoreSelector = {
        job: { re: 'thanos-store(-[0-9]+)?' },
        type: 'monitoring',
        grpc_type: 'unary',
      },

      apdex: histogramApdex(
        histogram='grpc_server_handling_seconds_bucket',
        selector=thanosStoreSelector,
        satisfiedThreshold=1,
        toleratedThreshold=3,
        metricsFormat='openmetrics'
      ),

      requestRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=thanosStoreSelector
      ),

      errorRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=thanosStoreSelector { grpc_code: { ne: 'OK' } }
      ),

      significantLabels: ['pod'],

      toolingLinks: [
        toolingLinks.kibana(title='Thanos Store (gprd)', index='monitoring_gprd', tag='monitoring.systemd.thanos-store'),
        toolingLinks.kibana(title='Thanos Store (ops)', index='monitoring_ops', tag='monitoring.systemd.thanos-store'),
      ],
    },

    thanos_compactor: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Thanos compactor is responsible for compaction of Prometheus series data into blocks, which are stored in GCS buckets.
        It also handles downsampling. This SLI monitors compaction operations and compaction failures.
      |||,

      local thanosCompactorSelector = {
        job: 'thanos',
        type: 'monitoring',
      },

      requestRate: rateMetric(
        counter='thanos_compact_group_compactions_total',
        selector=thanosCompactorSelector
      ),

      errorRate: rateMetric(
        counter='thanos_compact_group_compactions_failures_total',
        selector=thanosCompactorSelector
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.kibana(title='Thanos Compact (gprd)', index='monitoring_gprd', tag='monitoring.systemd.thanos-compact'),
        toolingLinks.kibana(title='Thanos Compact (ops)', index='monitoring_ops', tag='monitoring.systemd.thanos-compact'),
      ],
    },

    // Prometheus Alert Manager Sender operations
    prometheus_alert_sender: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors all prometheus alert notifications that are generated by AlertManager.
        Alert delivery failure is considered a service-level failure.
      |||,

      local prometheusAlertsSelector = {
        job: 'prometheus',
        type: 'monitoring',
      },

      requestRate: rateMetric(
        counter='prometheus_notifications_sent_total',
        selector=prometheusAlertsSelector
      ),

      errorRate: rateMetric(
        counter='prometheus_notifications_errors_total',
        selector=prometheusAlertsSelector
      ),

      significantLabels: ['fqdn', 'pod', 'alertmanager'],
    },

    thanos_rule_alert_sender: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors alerts generated by Thanos Ruler.
        Alert delivery failure is considered a service-level failure.
      |||,

      local thanosRuleAlertsSelector = {
        job: 'thanos',
        type: 'monitoring',
      },

      requestRate: rateMetric(
        counter='thanos_alert_sender_alerts_sent_total',
        selector=thanosRuleAlertsSelector
      ),

      errorRate: rateMetric(
        counter='thanos_alert_sender_errors_total',
        selector=thanosRuleAlertsSelector
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.kibana(title='Thanos Rule', index='monitoring_ops', tag='monitoring.systemd.thanos-rule'),
      ],
    },

    // This component represents the Google Load Balancer in front
    // of the internal Grafana instance at dashboards.gitlab.net
    grafana_google_lb: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=false,
      // LB automatically created by the k8s ingress
      loadBalancerName='k8s2-um-4zodnh0s-monitoring-grafana-lhbkv8d3',
      projectId='gitlab-ops',
      trafficCessationAlertConfig=false
    ),

    prometheus: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors Prometheus instances via the HTTP interface.
        5xx responses are considered errors.
      |||,

      local prometheusSelector = {
        job: { re: 'prometheus.*', ne: 'prometheus-metamon' },
        type: 'monitoring',
      },

      apdex: histogramApdex(
        histogram='prometheus_http_request_duration_seconds_bucket',
        selector=prometheusSelector,
        satisfiedThreshold=1,
        toleratedThreshold=3
      ),

      requestRate: rateMetric(
        counter='prometheus_http_requests_total',
        selector=prometheusSelector
      ),

      errorRate: rateMetric(
        counter='prometheus_http_requests_total',
        selector=prometheusSelector { code: { re: '^5.*' } }
      ),

      significantLabels: ['fqdn', 'pod', 'handler'],

      toolingLinks: [
        toolingLinks.kibana(title='Prometheus (gprd)', index='monitoring_gprd', tag='monitoring.prometheus'),
        toolingLinks.kibana(title='Prometheus (ops)', index='monitoring_ops', tag='monitoring.prometheus'),
      ],
    },

    // This component represents rule evaluations in
    // Prometheus and thanos ruler
    rule_evaluation: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors Prometheus recording rule evaluations. Recording rule evalution failures are considered to be
        service failures.
      |||,

      local selector = { type: 'monitoring' },

      requestRate: rateMetric(
        counter='prometheus_rule_evaluations_total',
        selector=selector
      ),

      errorRate: rateMetric(
        counter='prometheus_rule_evaluation_failures_total',
        selector=selector
      ),

      significantLabels: ['fqdn', 'pod'],
    },

    grafana: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      monitoringThresholds+: {
        apdexScore: 0.92,
      },

      description: |||
        Grafana builds and displays dashboards querying Thanos, Elasticsearch and other datasources.
        This SLI monitors the Grafana HTTP interface.
      |||,

      local grafanaSelector = {
        job: 'grafana',
        type: 'monitoring',
        shard: 'default',
      },

      apdex: histogramApdex(
        histogram='grafana_http_request_duration_seconds_bucket',
        selector=grafanaSelector,
        satisfiedThreshold=5,
        metricsFormat='openmetrics'
      ),

      requestRate: rateMetric(
        counter='grafana_http_request_duration_seconds_bucket',
        selector=grafanaSelector { le: '+Inf' },
      ),

      errorRate: rateMetric(
        counter='grafana_http_request_duration_seconds_bucket',
        selector=grafanaSelector { le: '+Inf', code: { re: '^5.*' } }
      ),

      significantLabels: ['pod'],
    },

    grafana_datasources: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Grafana builds and displays dashboards querying Thanos, Elasticsearch and other datasources.
        This SLI monitors the requests from Grafana to its datasources.
      |||,

      local grafanaSelector = {
        job: 'grafana',
        type: 'monitoring',
        shard: 'default',
      },

      requestRate: rateMetric(
        counter='grafana_datasource_request_total',
        selector=grafanaSelector,
      ),

      errorRate: rateMetric(
        counter='grafana_datasource_request_total',
        selector=grafanaSelector { code: { re: '^5.*' } }
      ),

      significantLabels: ['pod', 'datasource'],
    },

    grafana_image_renderer: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      monitoringThresholds+: {
        apdexScore: 0.92,
      },

      description: |||
        The Grafana Image Renderer exports Grafana dashboards or panels to PNG for external use.
        This SLI monitors the Grafana Image Renderer HTTP interface.
      |||,

      local grafanaSelector = {
        job: 'grafana-image-renderer',
        type: 'monitoring',
        shard: 'default',
      },

      apdex: histogramApdex(
        histogram='grafana_image_renderer_service_http_request_duration_seconds_bucket',
        selector=grafanaSelector,
        satisfiedThreshold=30,
      ),

      requestRate: rateMetric(
        counter='grafana_image_renderer_service_http_request_duration_seconds_bucket',
        selector=grafanaSelector { le: '+Inf' },
      ),

      errorRate: rateMetric(
        counter='grafana_image_renderer_service_http_request_duration_seconds_bucket',
        selector=grafanaSelector { le: '+Inf', status_code: { re: '^5.*' } }
      ),

      significantLabels: ['pod'],
    },

    thanos_memcached: {
      userImpacting: false,
      serviceAggregation: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Various memcached instances support our thanos infrastructure, for the
        store and query-frontend components.
      |||,

      local selector = { type: 'monitoring' },

      apdex: histogramApdex(
        histogram='thanos_memcached_operation_duration_seconds_bucket',
        satisfiedThreshold=0.5,
        selector=selector,
        metricsFormat='openmetrics'
      ),

      requestRate: rateMetric(
        counter='thanos_memcached_operations_total',
        selector=selector,
      ),

      errorRate: rateMetric(
        counter='thanos_memcached_operation_failures_total',
        selector=selector,
      ),

      significantLabels: ['operation', 'reason'],
    },
  },

  skippedMaturityCriteria: maturityLevels.skip({
    'Service exists in the dependency graph': 'Thanos is an independent internal observability tool. It fetches metrics from other services, but does not interact with them, functionally',
  }),
})
