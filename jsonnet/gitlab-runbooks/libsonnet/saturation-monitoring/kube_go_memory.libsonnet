local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

// HACK: containers running Go
// Ideally we shouldn't need to keep this updated manually
local goContainers = ['gitlab-pages', 'gitlab-workhorse', 'kas', 'registry', 'thanos-store'];

{
  kube_go_memory: resourceSaturationPoint({
    title: 'Go Memory Utilization per Node',
    severity: 's4',
    dangerouslyThanosEvaluated: true,
    horizontallyScalable: true,
    appliesTo: std.setInter(
      std.set(metricsCatalog.findServicesWithTag(tag='golang')),
      std.set(metricsCatalog.findKubeProvisionedServices())
    ),
    description: |||
      Measures Go memory usage as a percentage of container memory limit
    |||,
    grafana_dashboard_uid: 'sat_kube_go_memory',
    resourceLabels: ['cluster', 'pod'],
    queryFormatConfig: {
      goContainers: std.join('|', goContainers),
    },
    // TODO: unfortunately thanos-store containers have a mismatch between the application
    // metrics and the container metrics in that the container metrics are missing the
    // required `stage` and `shard` labels.
    // Once this is fixed, the second part of the `OR` conjuction below can
    // be removed.
    // Tracked in https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/13593
    query: |||
      (
        go_memstats_alloc_bytes{%(selector)s}
        / on(%(aggregationLabels)s) group_left()
        topk by(%(aggregationLabels)s) (1,
          container_spec_memory_limit_bytes:labeled{container=~"%(goContainers)s",%(selector)s}
        )
      )
      or
      (
        go_memstats_alloc_bytes{type="monitoring", %(selector)s}
        / on(environment, tier, type, cluster, pod) group_left()
        topk by (environment, tier, type, cluster, pod) (1,
          container_spec_memory_limit_bytes:labeled{type="monitoring", container=~"%(goContainers)s"}
        )
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.98,
    },
  }),
}
