local googleCloudRunComponents = import './lib/google_cloud_run_components.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'pvs',
  tier: 'sv',
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  provisioning: {
    vms: false,
    kubernetes: false,
  },
  serviceLevelIndicators: {
    http: googleCloudRunComponents.googleCloudRun(
      userImpacting=true,
      configurationName='pipeline-validation-service',
      projectId='glsec-trust-safety-live',
      gcpRegion='us-central1',
      trafficCessationAlertConfig=true,
      apdexSatisfactoryLatency=4096,  // Latency, in milliseconds
      team='pipeline_validation',
      additionalToolingLinks=[
        toolingLinks.kibana(title='PVS', index='pvs', includeMatchersForPrometheusSelector=false),
      ]
    ),
  },
})
