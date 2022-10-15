local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'google_load_balancer' });
local stackdriverLogs = import './stackdriver_logs.libsonnet';

{
  googleLoadBalancer(
    instanceId,
    project='gitlab-production',
  )::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Google Load Balancer',
          url: 'https://console.cloud.google.com/net-services/loadbalancing/details/http/%(instanceId)s?project=%(project)s' % {
            instanceId: instanceId,
            project: project,
          },
        }),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: Loadbalancer Access Logs',
          queryHash={
            'resource.type': 'http_load_balancer',
            'resource.labels.url_map_name': instanceId,
          },
          project=project
        )(options),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: Loadbalancer Access 5xx Logs',
          queryHash={
            'resource.type': 'http_load_balancer',
            'resource.labels.url_map_name': instanceId,
            'httpRequest.status': { gte: 500 },
          },
          project=project
        )(options),
      ],
}
