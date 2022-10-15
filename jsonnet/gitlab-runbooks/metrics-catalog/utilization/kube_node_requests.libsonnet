local utilizationMetric = (import 'servicemetrics/utilization_metric.libsonnet').utilizationMetric;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  kube_node_cpu_requests: utilizationMetric({
    title: 'Kube Node CPU Requests Utilization',
    unit: 'percent',
    appliesTo: metricsCatalog.findKubeProvisionedServicesWithDedicatedNodePool(),
    description: |||
      Kubernetes pods are requesting cpu shares, to indicate how many pods may fit on a node.
      If all cpu shares on a node have been requested by pods, no more pods can be scheduled
      on a node. High requests utilization on a node is desired, as it indicates that
      pods fit well into the allocatable space and node resources do not stay unused.
    |||,
    resourceLabels: ['type', 'shard'],
    query: |||
      avg by (%(aggregationLabels)s,shard) (
        sum by (%(aggregationLabels)s,node) (
          kube_pod_container_resource_requests{resource="cpu", unit="core"}
        )
        / on (node) group_left(cluster,env,tier,type,stage,shard)
        kube_node_status_allocatable:labeled{%(selector)s,resource="cpu"}
      )
      * 100
    |||,
  }),

  kube_node_memory_requests: utilizationMetric({
    title: 'Kube Node Memory Requests Utilization',
    unit: 'percent',
    appliesTo: metricsCatalog.findKubeProvisionedServicesWithDedicatedNodePool(),
    description: |||
      Kubernetes pods are requesting memory, to indicate how many pods may fit on a node.
      If all memory on a node has been requested by pods, no more pods can be scheduled
      on a node. High requests utilization on a node is desired, as it indicates that
      pods fit well into the allocatable space and node resources do not stay unused.
    |||,
    resourceLabels: ['type', 'shard'],
    query: |||
      avg by (%(aggregationLabels)s,shard) (
        sum by (%(aggregationLabels)s,node) (
          kube_pod_container_resource_requests{resource="memory", unit="byte"}
        )
        / on (node) group_left(cluster,env,tier,type,stage,shard)
        kube_node_status_allocatable:labeled{%(selector)s,resource="memory"}
      )
      * 100
    |||,
  }),
}
