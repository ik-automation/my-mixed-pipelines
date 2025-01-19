local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'gke_deployment' });
local stackdriverLogs = import './stackdriver_logs.libsonnet';

{
  gkeDeployment(
    deployment,
    region='us-east1',
    cluster='gprd-gitlab-gke',
    namespace='gitlab',
    project='gitlab-production',
    type=null,
    shard=null,
    containerName=null,
  )::
    function(options)
      local formatConfig = {
        deployment: deployment,
        region: region,
        cluster: cluster,
        namespace: namespace,
        project: project,
      };

      [
        toolingLinkDefinition({
          title: 'GKE Deployment: %(deployment)s' % formatConfig,
          url: 'https://console.cloud.google.com/kubernetes/deployment/%(region)s/%(cluster)s/%(namespace)s/%(deployment)s/overview?project=%(project)s' % formatConfig,
        }),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: GKE Container Logs',
          queryHash={
            'resource.type': 'k8s_container',
            'resource.labels.project_id': project,
            'resource.labels.cluster_name': cluster,
            'resource.labels.namespace_name': namespace,
            'labels."k8s-pod/type"': type,
            'labels."k8s-pod/shard"': shard,
            'resource.labels.container_name': containerName,
          },
          project=project
        )(options),
      ],
}
