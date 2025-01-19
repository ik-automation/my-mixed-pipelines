local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local customRateQuery = metricsCatalog.customRateQuery;
local maturityLevels = import 'service-maturity/levels.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'kube',
  tier: 'inf',
  serviceIsStageless: true,  // kube does not have a cny stage
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.9995,
  },
  /*
   * Our anomaly detection uses normal distributions and the monitoring service
   * is prone to spikes that lead to a non-normal distribution. For that reason,
   * disable ops-rate anomaly detection on this service.
   */
  disableOpsRatePrediction: true,
  serviceDependencies: {
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      podSelector=null,
      hpaSelector=null,
      ingressSelector=null,
      deploymentSelector=null,
      nodeSelector={ type: 'kube' },
      nodeStaticLabels={ stage: 'main' },
    ),
  },
  serviceLevelIndicators: {
    apiserver: {
      userImpacting: false,
      featureCategory: 'not_owned',
      team: 'sre_reliability',
      description: |||
        The Kubernetes API server validates and configures data for the api objects which
        include pods, services, and others. The API Server services REST operations
        and provides the frontend to the cluster's shared state through which all other components
        interact.

        This SLI measures all non-health-check endpoints. Long-polling endpoints are excluded from apdex scores.
      |||,

      local baseSelector = {
        job: 'apiserver',
        scope: { ne: '' },  // scope="" is used for health check endpoints
      },

      apdex: histogramApdex(
        histogram='apiserver_request_duration_seconds_bucket',
        selector=baseSelector { verb: { ne: 'WATCH' } },  // Exclude long-polling
        satisfiedThreshold=1,
      ),

      requestRate: rateMetric(
        counter='apiserver_request_total',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='apiserver_request_total',
        selector=baseSelector { code: { re: '5..' } }
      ),

      significantLabels: ['scope', 'resources'],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Kubernetes Cluster Logs',
          queryHash={
            'resource.type': 'k8s_cluster',
          },
        ),
        toolingLinks.stackdriverLogs(
          'Kubernetes Cluster Warning Logs',
          queryHash={
            'resource.type': 'k8s_cluster',
            severity: { one_of: ['EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR', 'WARNING'] },
          },
        ),
        toolingLinks.kibana(title='Kubernetes Cluster Logs (Kibana)', index='gkeKube'),
      ],
    },

    cluster_scaleups: {
      userImpacting: false,
      featureCategory: 'not_owned',
      team: 'sre_reliability',
      trafficCessationAlertConfig: false,
      description: |||
        We rely on the GKE Cluster Autoscaler (https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler) to
        automatically scale up and scale down our Kubernetes fleets.

        Each decision by the cluster autoscaler to scale up is treated as an operation, and each cluster scaleup failure is
        treated as an error.
      |||,

      staticLabels: {
        tier: 'inf',
        stage: 'main',
      },

      monitoringThresholds: {
        errorRatio: 0.95,
      },

      // Unfortunately Log-Based Metrics aren't counters, so we need to fill-in-the-gaps when
      // events don't occur. We use the `group by` term for these cases.
      requestRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          avg_over_time(stackdriver_k_8_s_cluster_logging_googleapis_com_user_k_8_s_cluster_autoscaler_scaleup_decisions[%(burnRate)s])
        )
        or
        0 * group by (%(aggregationLabels)s) (
          avg_over_time(stackdriver_k_8_s_cluster_logging_googleapis_com_user_k_8_s_cluster_autoscaler_scaleup_decisions[6h])
        )
      |||),

      errorRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          avg_over_time(stackdriver_k_8_s_cluster_logging_googleapis_com_user_k_8_s_cluster_autoscaler_scaleup_errors[%(burnRate)s])
        )
      |||),

      significantLabels: ['cluster_name'],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Kubernetes Autoscaler Logs',
          queryHash={
            'resource.type': 'k8s_cluster',
            logName: 'projects/gitlab-production/logs/container.googleapis.com%2Fcluster-autoscaler-visibility',
          },
        ),
        toolingLinks.stackdriverLogs(
          'Kubernetes Autoscaler Errors',
          queryHash={
            'resource.type': 'k8s_cluster',
            logName: 'projects/gitlab-production/logs/container.googleapis.com%2Fcluster-autoscaler-visibility',
            'jsonPayload.resultInfo.results.errorMsg.messageId': { exists: true },
          },
        ),
      ],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Developer guides exist in developer documentation': 'Application logic does not interact with kube',
    'Service exists in the dependency graph': 'This service is managed by GKE at the moment. It does not interfact directly with any other services',
  }),
})
