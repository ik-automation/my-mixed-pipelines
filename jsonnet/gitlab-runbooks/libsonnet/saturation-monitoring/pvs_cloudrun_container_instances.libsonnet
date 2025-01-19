local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  pvs_cloudrun_container_instances: resourceSaturationPoint({
    title: 'Cloud Run Container Instance Utilization',
    severity: 's3',
    horizontallyScalable: true,  // Increase the maximum number of instances past 100
    appliesTo: ['pvs'],
    description: |||
      Cloud Run is configured with a maximum number of container instances. When this is saturated, Google Cloud Run
      will no longer scale up.

      More information available at https://cloud.google.com/run/docs/configuring/max-instances.
    |||,
    grafana_dashboard_uid: 'sat_pvs_cloudrun_ctr_instances',
    resourceLabels: ['state'],
    queryFormatConfig: {
      // Hard-coded since Google don't expose this via Stackdriver.
      // This value should match the Auto-scaling/Max instances found in
      // https://console.cloud.google.com/run/detail/us-central1/pipeline-validation-service/revisions?project=glsec-trust-safety-live
      maximumContainerConcurrency: 100,
    },
    staticLabels: {
      type: 'pvs',
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      sum by (%(aggregationLabels)s) (
        stackdriver_cloud_run_revision_run_googleapis_com_container_instance_count{
          configuration_name="pipeline-validation-service",
          %(selector)s
        }
      )
      /
      %(maximumContainerConcurrency)g
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
