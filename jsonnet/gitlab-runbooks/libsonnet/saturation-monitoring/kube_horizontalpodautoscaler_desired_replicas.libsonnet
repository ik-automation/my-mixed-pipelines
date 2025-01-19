local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local sidekiqHelpers = import './services/lib/sidekiq-helpers.libsonnet';

{
  kube_horizontalpodautoscaler_desired_replicas: resourceSaturationPoint({
    title: 'Horizontal Pod Autoscaler Desired Replicas',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findKubeProvisionedServices(first='web'),
    description: |||
      The [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
      automatically scales the number of Pods in a deployment based on metrics.

      The Horizontal Pod Autoscaler has a configured upper maximum. When this
      limit is reached, the HPA will not increase the number of pods and other
      resource saturation (eg, CPU, memory) may occur.
    |||,
    alertRunbook: 'docs/kube/kubernetes.md#hpascalecapability',
    grafana_dashboard_uid: 'sat_kube_horizontalpodautoscaler',
    resourceLabels: ['horizontalpodautoscaler', 'shard'],
    query: |||
      kube_horizontalpodautoscaler_status_desired_replicas:labeled{%(selector)s, shard!~"%(ignored_sidekiq_shards)s"}
      /
      kube_horizontalpodautoscaler_spec_max_replicas:labeled{%(selector)s, shard!~"%(ignored_sidekiq_shards)s"}
    |||,
    queryFormatConfig: {
      // Ignore non-autoscaled shards and throttled shards
      ignored_sidekiq_shards: std.join('|', sidekiqHelpers.shards.listFiltered(function(shard) !shard.autoScaling || shard.urgency == 'throttled')),
    },
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '25m',
    },
  }),
}
