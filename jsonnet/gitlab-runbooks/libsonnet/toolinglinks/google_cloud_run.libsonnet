local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'google_load_balancer' });
local stackdriverLogs = import './stackdriver_logs.libsonnet';

{
  googleCloudRun(
    serviceName,
    project,
    gcpRegion
  )::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Google Cloud Run Console',
          url: 'https://console.cloud.google.com/run/detail/%(gcpRegion)s/%(serviceName)s/metrics?project=%(project)s' % {
            gcpRegion: gcpRegion,
            serviceName: serviceName,
            project: project,
          },
        }),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: Cloud Run Access Logs',
          queryHash={
            'resource.type': 'cloud_run_revision',
            'resource.labels.service_name': serviceName,
          },
          project=project
        )(options),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: Cloud Run Access 5xx Logs',
          queryHash={
            'resource.type': 'cloud_run_revision',
            'resource.labels.service_name': serviceName,
            'httpRequest.status': { gte: 500 },
          },
          project=project
        )(options),
      ],
}
