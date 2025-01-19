local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  cgroup_memory: resourceSaturationPoint({
    title: 'Cgroup Memory Utilization per Node',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['gitaly', 'praefect'],
    description: |||
      Cgroup memory utilization per node.

      Some services, notably Gitaly, are configured to run within a cgroup with a memory limit lower than the
      memory limit for the node. This ensures that a traffic spike to Gitaly does not affect other services on the node.

      If this resource is becoming saturated, this may indicate traffic spikes to Gitaly, abuse or possibly resource leaks in
      the application. Gitaly or other git processes may be killed by the OOM killer when this resource is saturated.
    |||,
    grafana_dashboard_uid: 'sat_cgroup_memory',
    resourceLabels: ['fqdn'],
    query: |||
      (
        container_memory_usage_bytes{id="/system.slice/gitlab-runsvdir.service", %(selector)s} -
        container_memory_cache{id="/system.slice/gitlab-runsvdir.service", %(selector)s} -
        container_memory_swap{id="/system.slice/gitlab-runsvdir.service", %(selector)s}
      )
      /
      container_spec_memory_limit_bytes{id="/system.slice/gitlab-runsvdir.service", %(selector)s}
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
