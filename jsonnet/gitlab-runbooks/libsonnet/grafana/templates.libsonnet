local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local defaultPrometheusDatasource = (import 'gitlab-metrics-config.libsonnet').defaultPrometheusDatasource;

{
  gkeCluster::
    template.new(
      'cluster',
      '$PROMETHEUS_DS',
      'label_values(kube_pod_container_info{environment="$environment"}, cluster)',
      current='gprd-gitlab-gke ',
      refresh='load',
      sort=1,
    ),
  namespace::
    template.new(
      'namespace',
      '$PROMETHEUS_DS',
      'label_values(kube_pod_container_info{environment="$environment"}, namespace)',
      refresh='load',
    ),
  // Specify the default namespace to be utilized for this template
  namespaceDefault(namespace)::
    template.new(
      'namespace',
      '$PROMETHEUS_DS',
      'label_values(kube_pod_container_info{environment="$environment"}, namespace)',
      current=namespace,
      refresh='load',
      sort=1,
    ),
  // TODO: figure out to replace the below template with the above
  namespaceGitlab::
    template.new(
      'namespace',
      '$PROMETHEUS_DS',
      'label_values(kube_pod_container_info{environment="$environment"}, namespace)',
      current='gitlab',
      refresh='load',
      sort=1,
    ),
  ds::
    template.datasource(
      'PROMETHEUS_DS',
      'prometheus',
      defaultPrometheusDatasource,
    ),
  environment::
    template.new(
      'environment',
      '$PROMETHEUS_DS',
      'label_values(gitlab_service_ops:rate, environment)',
      current='gprd',
      refresh='load',
      sort=1,
    ),
  defaultEnvironment::
    {
      current: {
        text: 'gprd',
        value: 'gprd',
      },
      hide: 1,
      label: null,
      name: 'environment',
      options: [
        {
          selected: true,
          text: 'gprd',
          value: 'gprd',
        },
      ],
      query: 'gprd',
      skipUrlSync: false,
      type: 'constant',
    },
  Node::
    template.new(
      'Node',
      '$PROMETHEUS_DS',
      'query_result(count(count_over_time(kube_node_labels{environment="$environment", cluster="$cluster"}[1w])) by (label_kubernetes_io_hostname))',
      allValues='.*',
      current='NewMergeRequestWorker',
      includeAll=true,
      refresh='time',
      regex='/.*="(.*)".*/',
      sort=0,
    ),
  type::
    template.new(
      'type',
      '$PROMETHEUS_DS',
      'label_values(gitlab_service_ops:rate{environment="$environment"}, type)',
      current='web',
      refresh='load',
      sort=1,
    ),
  sigma::
    template.custom(
      'sigma',
      '0.5,1,1.5,2,2.5,3',
      '2',
    ),
  component::
    template.new(
      'component',
      '$PROMETHEUS_DS',
      'label_values(gitlab_component_ops:rate{environment="$environment", type="$type", stage="$stage"}, component)',
      current='',
      refresh='load',
      sort=1,
    ),
  // Once the stage change is fully rolled out, change the default to main
  stage::
    template.custom(
      'stage',
      'main,cny,',
      'main',
    ),
  saturationComponent::
    template.new(
      'component',
      '$PROMETHEUS_DS',
      'label_values(gitlab_component_saturation:ratio{environment="$environment", type="$type"}, component)',
      current='cpu',
      refresh='load',
      sort=1,
    ),
  sidekiqQueue::
    template.new(
      'queue',
      '$PROMETHEUS_DS',
      'label_values(sidekiq_jobs_completion_seconds_bucket{environment="$environment"}, queue)',
      current='new_merge_request',
      refresh='load',
      sort=1,
    ),
  railsController(default)::
    template.new(
      'controller',
      '$PROMETHEUS_DS',
      'label_values(controller_action:gitlab_transaction_duration_seconds_count:rate1m{environment="$environment", type="$type"}, controller)',
      current=default,
      refresh='load',
      sort=1,
    ),
  railsControllerAction(default)::
    template.new(
      'action',
      '$PROMETHEUS_DS',
      'label_values(controller_action:gitlab_transaction_duration_seconds_count:rate1m{environment="$environment", type="$type", controller="$controller"}, action)',
      current=default,
      refresh='load',
      sort=1,
      multi=true,
      includeAll=true,
    ),
  constant(name, value)::
    {
      current: {
        text: value,
        value: value,
      },
      label: null,
      name: name,
      options: [
        {
          selected: true,
          text: value,
          value: value,
        },
      ],
      query: value,
      skipUrlSync: true,
      type: 'constant',
    },
  fqdn(
    query,
    current='',
    multi=false
  )::
    template.new(
      'fqdn',
      '$PROMETHEUS_DS',
      'label_values(' + query + ', fqdn)',
      current=current,
      multi=multi,
      refresh='load',
      sort=1,
    ),
  productStage(multi=true)::
    template.new(
      'product_stage',
      '$PROMETHEUS_DS',
      'label_values(gitlab:feature_category:stage_group:mapping{monitor="global"}, product_stage)',
      multi=multi,
      refresh='load',
      includeAll=true,
      allValues='.*',
    ),
  stageGroup(multi=true)::
    template.new(
      'stage_group',
      '$PROMETHEUS_DS',
      'label_values(gitlab:feature_category:stage_group:mapping{monitor="global", product_stage=~"$product_stage"}, stage_group)',
      multi=multi,
      refresh='load',
      includeAll=true,
      allValues='.*',
    ),
  slaType::
    template.new(
      'sla_type',
      '$PROMETHEUS_DS',
      'label_values(sla:gitlab:ratio, sla_type)',
      current='weighted_v2.1',
      refresh='load',
      sort=1,
    ),
}
