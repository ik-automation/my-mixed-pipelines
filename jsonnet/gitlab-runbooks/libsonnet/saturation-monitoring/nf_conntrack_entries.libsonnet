local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  nf_conntrack_entries: resourceSaturationPoint({
    title: 'conntrack Entries per Node',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findVMProvisionedServices(first='patroni'),
    description: |||
      Netfilter connection tracking table utilization per node.

      When saturated, new connection attempts (incoming SYN packets) are dropped with no reply, leaving clients to slowly retry (and typically fail again) over the next several seconds.  When packets are being dropped due to this condition, kernel will log the event as: "nf_conntrack: table full, dropping packet".
    |||,
    grafana_dashboard_uid: 'sat_conntrack',
    resourceLabels: ['fqdn', 'instance'],  // Use both labels until https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10299 arrives
    query: |||
      max_over_time(node_nf_conntrack_entries{%(selector)s}[%(rangeInterval)s])
      /
      node_nf_conntrack_entries_limit{%(selector)s}
    |||,
    slos: {
      soft: 0.95,
      hard: 0.98,
    },
  }),
}
