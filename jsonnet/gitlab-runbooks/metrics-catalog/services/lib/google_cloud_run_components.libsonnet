local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;

{
  // Creates a Google Cloud Run component
  // for monitoring a Cloud Run deployment via stackdriver metrics
  // Metric documentation can be found at https://cloud.google.com/monitoring/api/metrics_gcp#gcp-run
  // loadBalancerName: the name of the load balancer
  // projectId: the Google ProjectID that the load balancer is declared in
  googleCloudRun(
    userImpacting,
    configurationName,
    projectId,
    gcpRegion,  // Don't confuse this with the prometheus `region` which is where we collect the metrics, not where google host Cloud Run
    trafficCessationAlertConfig=true,
    apdexSatisfactoryLatency=null,
    team=null,
    additionalToolingLinks=[]
  )::
    local baseSelector = { configuration_name: configurationName, project_id: projectId };

    metricsCatalog.serviceLevelIndicatorDefinition({
      userImpacting: userImpacting,
      [if team != null then 'team']: team,
      trafficCessationAlertConfig: trafficCessationAlertConfig,

      staticLabels: {
        // TODO: In future, we may need to allow other stages here too
        // in which case we'll need to use a scheme similar that the one
        // we use for HAPRoxy
        stage: 'main',
      },

      [if apdexSatisfactoryLatency != null then 'apdex']: histogramApdex(
        histogram='stackdriver_cloud_run_revision_run_googleapis_com_request_latencies_bucket',
        selector=baseSelector,
        satisfiedThreshold=apdexSatisfactoryLatency,
      ),

      requestRate: rateMetric(
        counter='stackdriver_cloud_run_revision_run_googleapis_com_request_count',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='stackdriver_cloud_run_revision_run_googleapis_com_request_count',
        selector=baseSelector { response_code_class: '5xx' },
      ),

      significantLabels: ['response_code'],

      toolingLinks: [
        toolingLinks.googleCloudRun(
          serviceName=configurationName,
          gcpRegion=gcpRegion,
          project=projectId
        ),
      ] + additionalToolingLinks,
    }),
}
