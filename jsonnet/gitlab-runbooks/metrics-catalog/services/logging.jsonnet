local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local derivMetric = metricsCatalog.derivMetric;
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'logging',
  tier: 'inf',

  serviceIsStageless: true,  // logging does not have a cny stage

  monitoringThresholds: {
    // apdexScore: 0.999,
    errorRatio: 0.999,
  },
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for logging

      podStaticLabels={ stage: 'main' },
    ),
  },
  kubeResources: {
    'fluentd-archiver': {
      kind: 'StatefulSet',
      containers: [
        'fluentd',
      ],
    },
    'fluentd-elasticsearch': {
      kind: 'DaemonSet',
      containers: [
        'fluentd-elasticsearch',
      ],
    },
    pubsubbeat: {
      kind: 'Deployment',
      containers: [
        'pubsubbeat',
      ],
    },
  },
  serviceLevelIndicators: {
    elasticsearch_searching_cluster: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This cluster SLI monitors searches issued to GitLab's logging ELK instance.
      |||,

      requestRate: derivMetric(
        counter='elasticsearch_indices_search_query_total',
        selector='type="logging"',
        clampMinZero=true,
      ),

      significantLabels: ['name'],

      toolingLinks: [
        toolingLinks.kibana(title='Monitoring Cluster', index='logging'),
      ],
    },

    elasticsearch_indexing_cluster: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This cluster SLI monitors log index operations to GitLab's logging ELK instance.
      |||,

      requestRate: derivMetric(
        counter='elasticsearch_indices_indexing_index_total',
        selector='type="logging"',
        clampMinZero=true,
      ),

      significantLabels: ['name'],

      toolingLinks: [
        toolingLinks.kibana(title='Monitoring Cluster', index='logging'),
      ],
    },

    elasticsearch_searching_index: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This index SLI monitors searches issued to GitLab's logging ELK instance.
      |||,

      requestRate: derivMetric(
        counter='elasticsearch_index_stats_search_query_total',
        selector='type="logging"',
        clampMinZero=true,
      ),

      significantLabels: ['index'],

      toolingLinks: [
        toolingLinks.kibana(title='Monitoring Cluster', index='logging'),
      ],
    },

    elasticsearch_indexing_index: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This index SLI monitors log index operations to GitLab's logging ELK instance.
      |||,

      requestRate: derivMetric(
        counter='elasticsearch_index_stats_indexing_index_total',
        selector='type="logging"',
        clampMinZero=true,
      ),

      significantLabels: ['index'],

      toolingLinks: [
        toolingLinks.kibana(title='Monitoring Cluster', index='logging'),
      ],
    },

    // This component represents the Google Load Balancer in front
    // of logs.gitlab.net instance
    kibana_googlelb: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=false,
      loadBalancerName='ops-prod-proxy',
      projectId='gitlab-ops',

      // No need to alert if Kibana isn't receiving traffic
      trafficCessationAlertConfig=false,
      extra={
        monitoringThresholds+: {
          errorRatio: 0.995,
        },
      }
    ),

    // Stackdriver component represents log messages
    // ingested in Google Stackdrive Logging in GCP
    stackdriver: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        This SLI monitors the total number of logs sent to GCP StackDriver logging.
      |||,

      requestRate: rateMetric(
        counter='stackdriver_gce_instance_logging_googleapis_com_log_entry_count',
      ),

      significantLabels: ['log', 'severity'],
    },

    pubsub_topics: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors pubsub topics.
      |||,

      requestRate: rateMetric(
        counter='stackdriver_pubsub_topic_pubsub_googleapis_com_topic_byte_cost',
        selector='type="monitoring"',
      ),

      significantLabels: ['topic_id'],

      toolingLinks: [
        toolingLinks.kibana(title='Pubsubbeat', index='pubsubbeat'),
      ],
    },

    pubsub_subscriptions: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors pubsub subscriptions.
      |||,

      requestRate: rateMetric(
        counter='stackdriver_pubsub_subscription_pubsub_googleapis_com_subscription_byte_cost',
        selector='type="monitoring"',
      ),

      significantLabels: ['subscription_id'],

      toolingLinks: [
        toolingLinks.kibana(title='Pubsubbeat', index='pubsubbeat'),
      ],
    },

    // This component tracks fluentd log output
    // across the entire fleet
    fluentd_log_output: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors fluentd log output and the number of output errors in fluentd.
      |||,

      requestRate: rateMetric(
        counter='fluentd_output_status_write_count',
      ),

      errorRate: rateMetric(
        counter='fluentd_output_status_num_errors'
      ),

      significantLabels: ['fqdn', 'pod', 'type'],
      serviceAggregation: false,

      toolingLinks: [
        toolingLinks.kibana(title='Fluentd', index='fluentd'),
      ],
    },

    // This components tracks pubsubbeat errors and outputs
    // across all topics
    pubsubbeat: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        This SLI monitors pubsubbeat errors.
      |||,

      requestRate: rateMetric(
        counter='pubsubbeat_libbeat_output_events'
      ),
      errorRate: rateMetric(
        counter='pubsubbeat_errors_total'
      ),

      significantLabels: ['pod'],
      serviceAggregation: false,
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Service exists in the dependency graph': 'The logging platform consumes logs via fluentd, but does not interact directly with any other services',
  }),
})
