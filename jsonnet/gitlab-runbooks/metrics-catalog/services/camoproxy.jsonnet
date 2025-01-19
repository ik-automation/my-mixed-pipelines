local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'camoproxy',
  tier: 'sv',
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.8,
  },
  serviceDependencies: {
    // If Camoproxy has any dependencies, we should add them here
  },
  serviceIsStageless: true,
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  kubeResources: {
    camoproxy: {
      kind: 'Deployment',
      containers: [
        'camoproxy',
      ],
    },
  },
  serviceLevelIndicators: {
    loadbalancer: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=true,
      // LB automatically created by the k8s ingress
      // https://console.cloud.google.com/net-services/loadbalancing/details/http/k8s2-um-8kvupfyn-camoproxy-camoproxy-6ygs428t?project=gitlab-production
      loadBalancerName='k8s2-um-8kvupfyn-camoproxy-camoproxy-6ygs428t',
      projectId='gitlab-production'
    ),

    server: {
      userImpacting: true,
      featureCategory: 'not_owned',
      upscaleLongerBurnRates: true,  // TODO: enabling this here to test that this approach works
      description: |||
        This SLI monitors the camoproxy server via its HTTP interface.
        5xx responses are considered to be failures. Note that this SLI
        is highly dependent on upstream proxy targets, not under the control
        of GitLab. We are unable to distinguish problems in the proxy from
        upstream problems. This should be taken into account for this SLI.
      |||,

      apdex: histogramApdex(
        histogram='camo_response_duration_seconds_bucket',
        satisfiedThreshold=5,
        toleratedThreshold=10
      ),

      requestRate: rateMetric(
        counter='camo_response_duration_seconds_bucket',
        selector={ le: '+Inf' },
      ),

      errorRate: rateMetric(
        counter='camo_proxy_reponses_failed_total',
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.kibana(title='Camoproxy', index='camoproxy'),
      ],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Service exists in the dependency graph': 'Camoproxy does not interact directly with any declared services in our system',
  }),
})
