local platformLinks = import './platform_links.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local quantilePanel = import 'grafana/quantile_panel.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local row = grafana.row;

local linksForService(type) =
  [
    platformLinks.backToOverview(type),
    platformLinks.dynamicLinks(type + ' Detail', 'type:' + type),
    platformLinks.kubenetesDetail(type),
  ];

local panelsForDeployment(serviceType, deployment, selectorHash) =
  local containerSelectorHash = selectorHash {
    type: serviceType,
    deployment: deployment,
  };

  local formatConfig = {
    type: serviceType,
    deployment: deployment,
    containerSelector: selectors.serializeHash(containerSelectorHash),
  };

  [
    basic.timeseries(
      title='%(deployment)s Deployment: CPU' % formatConfig,
      query=|||
        sum by(cluster) (
          rate(
            container_cpu_usage_seconds_total:labeled{
              %(containerSelector)s
            }[$__rate_interval]
          )
        )
      ||| % formatConfig,
      format='short',  // We measure this in total number of cores across the whole fleet, not percentage of a single core
      linewidth=1,
      legendFormat='{{ cluster }}',
    ),
    basic.timeseries(
      title='%(deployment)s Deployment: Memory' % formatConfig,
      query=|||
        sum by(cluster) (
          container_memory_working_set_bytes:labeled{
            %(containerSelector)s
          }
        )
      ||| % formatConfig,
      format='bytes',
      linewidth=1,
      legendFormat='{{ cluster }}',
    ),
    basic.networkTrafficGraph(
      title='%(deployment)s Deployment: Network IO' % formatConfig,
      sendQuery=|||
        sum by(cluster) (
          rate(
            container_network_transmit_bytes_total:labeled{
              %(containerSelector)s
            }[$__rate_interval]
          )
        )
      ||| % formatConfig,
      receiveQuery=|||
        sum by(cluster) (
          rate(
            container_network_receive_bytes_total:labeled{
              %(containerSelector)s
            }[$__rate_interval]
          )
        )
      ||| % formatConfig,
      legendFormat='{{ cluster }}',
    ),
  ];

local panelsForRequestsUtilization(serviceType, selectorHash) =
  local nodeSelectorHash = selectorHash {
    type: serviceType,
  };

  local formatConfig = {
    type: serviceType,
    nodeSelector: selectors.serializeHash(nodeSelectorHash),
  };

  [
    basic.timeseries(
      title='Node CPU Requests Utilization' % formatConfig,
      description=|||
        Ratio of requested CPU resources from allocatable resources.
        Ideally we have requests utilization close to 100%. Values are
        below 100% typically because pods do not fit well on nodes or
        because we might be bound by memory requests already.
      |||,
      query=|||
        sum by (node) (
          kube_pod_container_resource_requests{resource="cpu", unit="core"}
        )
        / on (node) group_left()
        kube_node_status_allocatable:labeled{%(nodeSelector)s,resource="cpu"}
      ||| % formatConfig,
      format='percentunit',
      linewidth=1,
      legendFormat='{{ node }}',
    ),
    basic.timeseries(
      title='Node Memory Requests Utilization' % formatConfig,
      description=|||
        Ratio of requested Memory resources from allocatable resources.
        Ideally we have requests utilization close to 100%. Values are
        below 100% typically because pods do not fit well on nodes or
        because we might be bound by CPU requests already.
      |||,
      query=|||
        sum by (node) (
          kube_pod_container_resource_requests{resource="memory", unit="byte"}
        )
        / on (node) group_left()
        kube_node_status_allocatable:labeled{%(nodeSelector)s,resource="memory"}
      ||| % formatConfig,
      format='percentunit',
      linewidth=1,
      legendFormat='{{ node }}',
    ),
  ];

local rowsForContainer(container, deployment, selectorHash) =
  local containerSelectorHash = selectorHash {
    deployment: deployment,
    container: container,
  };

  local formatConfig = {
    container: container,
    deployment: deployment,
    containerSelector: selectors.serializeHash(containerSelectorHash),
  };
  [
    /* First row */
    [
      quantilePanel.timeseries(
        title='%(container)s container/%(deployment)s deployment - CPU' % formatConfig,
        query=|||
          rate(
            container_cpu_usage_seconds_total:labeled{
              %(containerSelector)s
             }[$__rate_interval]
           )
        ||| % formatConfig,
        format='percentunit',
        linewidth=1,
        legendFormat='%s Container CPU' % [container],
      ),
      quantilePanel.timeseries(
        title='%(container)s container/%(deployment)s deployment - Memory' % formatConfig,
        query=|||
          container_memory_working_set_bytes:labeled{
            %(containerSelector)s
           }
        ||| % formatConfig,
        format='bytes',
        linewidth=1,
        legendFormat='%s Container Memory' % [container],
      ),
    ],
    /* Second row */
    [
      basic.timeseries(
        title='%(container)s container/%(deployment)s deployment - Container Waiting Reasons' % formatConfig,
        description='Why are containers waiting?',
        query=|||
          sum by (reason) (max_over_time(kube_pod_container_status_waiting_reason:labeled{
            %(containerSelector)s
          }[10m]))
        ||| % formatConfig,
        legendFormat='{{ reason }}',
        format='short',
        interval='1m',
        intervalFactor=3,
        yAxisLabel='Containers Terminated',
        sort='decreasing',
        legend_show=true,
        legend_rightSide=false,
        linewidth=0,
        fill=6,
        stack=true,
        decimals=0,
        stableId='container-terminations-%(container)s-%(deployment)s' % formatConfig,
      )
      .addSeriesOverride({
        alias: 'CrashLoopBackOff',
        color: 'purple',
      })
      .addSeriesOverride({
        alias: 'CreateContainerConfigError',
        color: 'yellow',
      })
      .addSeriesOverride({
        alias: 'CreateContainerError',
        color: 'orange',
      })
      .addSeriesOverride({
        alias: 'ErrImagePull',
        color: 'red',
      })
      .addSeriesOverride({
        alias: 'ImagePullBackOff',
        color: '#FA6400',  // dark orange
      })
      .addSeriesOverride({
        alias: 'InvalidImageName',
        color: '#C4162A',  // dark red
      })
      .addSeriesOverride({
        alias: 'ContainerCreating',
        color: 'blue',
      }),
      basic.timeseries(
        title='%(container)s container/%(deployment)s deployment - Container Terminations' % formatConfig,
        description='Why are containers terminating?',
        query=|||
          sum by (reason) (max_over_time(kube_pod_container_status_terminated_reason:labeled{
            %(containerSelector)s
          }[10m]))
        ||| % formatConfig,
        legendFormat='{{ reason }}',
        format='short',
        interval='1m',
        intervalFactor=3,
        yAxisLabel='Containers Terminated',
        sort='decreasing',
        legend_show=true,
        legend_rightSide=false,
        linewidth=0,
        fill=6,
        stack=true,
        decimals=0,
        stableId='container-waiting-%(container)s-%(deployment)s' % formatConfig,
      )
      .addSeriesOverride({
        alias: 'Completed',
        color: 'blue',
      })
      .addSeriesOverride({
        alias: 'ContainerCannotRun',
        color: 'yellow',
      })
      .addSeriesOverride({
        alias: 'DeadlineExceeded',
        color: 'orange',
      })
      .addSeriesOverride({
        alias: 'Error',
        color: 'red',
      })
      .addSeriesOverride({
        alias: 'Evicted',
        color: '#FA6400',  // dark orange
      })
      .addSeriesOverride({
        alias: 'OOMKilled',
        color: '#C4162A',  // dark red
      }),
    ],
  ];

local dashboardsForService(type) =
  local serviceInfo = metricsCatalog.getService(type);
  local serviceHasDedicatedKubeNodePool = serviceInfo.hasDedicatedKubeNodePool();
  local deployments = std.objectFields(serviceInfo.kubeResources);
  local selector = {
    env: '$environment',
    environment: '$environment',
    type: type,
    [if serviceInfo.serviceIsStageless then null else 'stage']: '$stage',
  };

  {
    'kube-containers':
      basic.dashboard(
        'Kube Containers Detail',
        tags=[type, 'type:' + type, 'kube', 'kube detail'],
      )
      .addTemplateIf(std.objectHas(selector, 'stage'), templates.stage)
      .addPanels(
        layout.rows(
          std.flatMap(
            function(deployment)
              [
                row.new(title='%s deployment' % [deployment]),
              ]
              +
              std.flatMap(
                function(container) rowsForContainer(container, deployment, selector),
                serviceInfo.kubeResources[deployment].containers
              ),
            deployments
          ),
          rowHeight=8
        )
      )
      .trailer()
      + {
        links+: linksForService(type),
      },

    'kube-deployments':
      basic.dashboard(
        'Kube Deployment Detail',
        tags=[type, 'type:' + type, 'kube', 'kube detail'],
      )
      .addTemplateIf(std.objectHas(selector, 'stage'), templates.stage)
      .addPanels(
        layout.rows(
          std.flatMap(
            function(deployment)
              [
                row.new(title='%s deployment' % [deployment]),
              ]
              +
              [
                panelsForDeployment(type, deployment, selector),
              ],
            deployments
          )
          +
          (
            if serviceHasDedicatedKubeNodePool then
              [panelsForRequestsUtilization(type, selector)]
            else
              []
          ),
          rowHeight=8
        )
      )
      .trailer()
      + {
        links+: linksForService(type),
      },
  };

local deploymentOverview(type, selector, startRow=1) =
  local serviceInfo = metricsCatalog.getService(type);
  local deployments = std.objectFields(serviceInfo.kubeResources);
  local serviceHasDedicatedKubeNodePool = serviceInfo.hasDedicatedKubeNodePool();

  // Add links to direct users to kubernetes specific dashboards
  local links = [{
    title: '☸️ %s Kubernetes Deployment Detail' % [type],
    url: '/d/%s-kube-deployments?${__url_time_range}&${__all_variables}' % [type],
  }, {
    title: '☸️ %s Kubernetes Container Detail' % [type],
    url: '/d/%s-kube-containers?${__url_time_range}&${__all_variables}' % [type],
  }];

  layout.rows(
    std.map(
      function(deployment)
        std.map(
          function(panel)
            panel {
              links: links,
            },
          panelsForDeployment(type, deployment, selector)
        ),
      deployments
    ) + (
      if serviceHasDedicatedKubeNodePool then
        [panelsForRequestsUtilization(type, selector)]
      else
        []
    ),
    rowHeight=8,
    startRow=startRow
  );

{
  // Returns a set of kubernetes dashboards for a given service
  dashboardsForService:: dashboardsForService,

  // Generates a set of panels with an overview of the deployment
  deploymentOverview:: deploymentOverview,
}
