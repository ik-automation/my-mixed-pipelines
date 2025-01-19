local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  nat_host_port_allocation: resourceSaturationPoint({
    title: 'Cloud NAT Host Port Allocation',
    severity: 's3',

    // Technically, this is horizontally scalable, but requires us to send out
    // adequate notice to our customers before scaling it up, eg
    // https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37444 and
    // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/3991 for examples
    horizontallyScalable: false,

    staticLabels: {
      type: 'nat',
      tier: 'inf',
      stage: 'main',
    },

    appliesTo: ['nat'],
    description: |||
      Cloud NAT will allocate a set of NAT ports to each host in a cluster. When these are all allocated,
      Cloud NAT may be unable to allocate any more.

      When this happens, processes may experience connection problems to external destinations. In the application these
      may manifest as SMTP connection drops or webhook delivery failures. In Kubernetes, nodes may fail while
      attempting to download images from external repositories.

      More details in the Cloud NAT documentation: https://cloud.google.com/nat/docs/ports-and-addresses.

      Note: when reviewing the detail chart for this saturation point, the instance_id can be resolved using
      `gcloud compute instances list --project gitlab-production --filter "id=$instance_id"`.
    |||,
    grafana_dashboard_uid: 'sat_nat_host_port_allocation',
    resourceLabels: ['instance_id', 'nat_gateway_name', 'zone'],
    burnRatePeriod: '5m',  // This needs to be high, since the StackDriver export only updates infrequently
    query: |||
      sum without(ip_protocol) (
        max_over_time(
          stackdriver_gce_instance_compute_googleapis_com_nat_port_usage{
            job="stackdriver",
            project_id=~"gitlab-production|gitlab-staging-1",
            %(selector)s
          }[%(rangeInterval)s]
        )
      )
      /
      sum without (nat_ip) (
        max_over_time(
          stackdriver_gce_instance_compute_googleapis_com_nat_allocated_ports{
            job="stackdriver",
            project_id=~"gitlab-production|gitlab-staging-1",
            %(selector)s
          }[%(rangeInterval)s]
        )
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
      alertTriggerDuration: '10m',  // Can be bursty, so only trigger after 10m
    },
  }),
}
