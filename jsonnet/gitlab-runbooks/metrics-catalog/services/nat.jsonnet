local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local customRateQuery = metricsCatalog.customRateQuery;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'nat',
  tier: 'inf',
  serviceIsStageless: true,  // nat does not have a cny stage
  monitoringThresholds: {
    // TODO: define thresholds for the NAT service
  },
  serviceDependencies: {
    frontend: true,
  },
  provisioning: {
    kubernetes: false,
    vms: false,
  },
  serviceLevelIndicators: {
    sent_tcp_packets: {
      userImpacting: true,
      featureCategory: 'not_owned',

      description: |||
        Monitors GCP Cloud NAT TCP packets sent.
        Request rate is measures in IP packets, sent by the Cloud NAT.
        Errors are dropped packets.

        High error rates could lead to network issues, including application errors, container fetch failures, etc.
      |||,

      requestRate: customRateQuery(|||
        sum by (environment) (
          avg_over_time(
            stackdriver_nat_gateway_router_googleapis_com_nat_sent_packets_count{metric_prefix="router.googleapis.com/nat",  ip_protocol="6", project_id=~"gitlab-staging-1|gitlab-production"}[%(burnRate)s]
          )
        )
      |||),

      // The error rate counts the number of dropped sent TCP packets by the Cloud NAT gateway
      errorRate: customRateQuery(|||
        sum by (environment) (
          avg_over_time(
            stackdriver_nat_gateway_router_googleapis_com_nat_dropped_sent_packets_count{metric_prefix="router.googleapis.com/nat",  ip_protocol="6", project_id=~"gitlab-staging-1|gitlab-production"}[%(burnRate)s]
          )
        )
      |||),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Cloud NAT Stackdriver Dropped Packet Logs',
          queryHash={
            'resource.type': 'nat_gateway',
            'jsonPayload.allocation_status': { ne: 'OK' },
          },
        ),
      ],
    },

    received_tcp_packets: {
      userImpacting: true,
      featureCategory: 'not_owned',

      description: |||
        Monitors GCP Cloud NAT TCP packets received.
        Request rate is measures in IP packets, received by the Cloud NAT.
        Errors are dropped packets.

        High error rates could lead to network issues, including application errors, container fetch failures, etc.
      |||,

      requestRate: customRateQuery(|||
        sum by (environment) (
          avg_over_time(
            stackdriver_nat_gateway_router_googleapis_com_nat_received_packets_count{metric_prefix="router.googleapis.com/nat",  ip_protocol="6", project_id=~"gitlab-staging-1|gitlab-production"}[%(burnRate)s]
          )
        )
      |||),

      // The error rate counts the number of dropped received TCP packets by the Cloud NAT gateway
      errorRate: customRateQuery(|||
        sum by (environment) (
          avg_over_time(
            stackdriver_nat_gateway_router_googleapis_com_nat_dropped_received_packets_count{metric_prefix="router.googleapis.com/nat",  ip_protocol="6", project_id=~"gitlab-staging-1|gitlab-production"}[%(burnRate)s]
          )
        )
      |||),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Cloud NAT Stackdriver Dropped Packet Logs',
          queryHash={
            'resource.type': 'nat_gateway',
            'jsonPayload.allocation_status': { ne: 'OK' },
          },
        ),
      ],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Developer guides exist in developer documentation': 'NAT is an infrastructure component, developers do not interact with it',
    'Structured logs available in Kibana': 'NAT is managed by GCP, thus the logs are avaiable in Stackdriver.',
  }),
})
