local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local keyMetrics = import './key_metrics.libsonnet';
local kubeServiceDashboards = import './kube_service_dashboards.libsonnet';
local metricsCatalogDashboards = import './metrics_catalog_dashboards.libsonnet';
local nodeMetrics = import './node_metrics.libsonnet';
local platformLinks = import './platform_links.libsonnet';
local saturationDetail = import './saturation_detail.libsonnet';
local systemDiagramPanel = import './system_diagram_panel.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');
local row = grafana.row;

local defaultEnvironmentSelector = gitlabMetricsConfig.grafanaEnvironmentSelector;

local listComponentThresholds(service) =
  std.prune([
    if service.serviceLevelIndicators[sliName].hasApdex() then
      ' * %s: %s' % [sliName, service.serviceLevelIndicators[sliName].apdex.describe()]
    else
      null
    for sliName in std.objectFields(service.serviceLevelIndicators)
  ]);

// This will build a description of the thresholds used in an apdex
local getApdexDescription(metricsCatalogServiceInfo) =
  std.join('  \n', [
    '_Apdex is a measure of requests that complete within a tolerable period of time for the service. Higher is better._\n',
    '### Component Thresholds',
    '_Satisfactory/Tolerable_',
  ] + listComponentThresholds(metricsCatalogServiceInfo));

local headlineMetricsRow(
  serviceType,
  startRow,
  metricsCatalogServiceInfo,
  selectorHash,
  showSaturationCell,
  stableIdPrefix='',
      ) =
  local hasApdex = metricsCatalogServiceInfo.hasApdex();
  local hasErrorRate = metricsCatalogServiceInfo.hasErrorRate();
  local hasRequestRate = metricsCatalogServiceInfo.hasRequestRate();
  local selectorHashWithExtras = selectorHash { type: serviceType };

  keyMetrics.headlineMetricsRow(
    serviceType=serviceType,
    startRow=startRow,
    rowTitle='🌡️ Aggregated Service Level Indicators (𝙎𝙇𝙄𝙨)',
    selectorHash=selectorHashWithExtras,
    stableIdPrefix=stableIdPrefix,
    showApdex=hasApdex,
    apdexDescription=getApdexDescription(metricsCatalogServiceInfo),
    showErrorRatio=hasErrorRate,
    showOpsRate=hasRequestRate,
    showSaturationCell=showSaturationCell,
    compact=true,
    rowHeight=8
  );

local overviewDashboard(
  type,
  title='Overview',
  uid=null,
  startRow=0,
  environmentSelectorHash=defaultEnvironmentSelector,
  saturationEnvironmentSelectorHash=defaultEnvironmentSelector,

  // Features
  showProvisioningDetails=true,
  showSystemDiagrams=true,
      ) =

  local metricsCatalogServiceInfo = metricsCatalog.getService(type);
  local saturationComponents = metricsCatalogServiceInfo.applicableSaturationTypes();

  local stageLabels =
    if metricsCatalogServiceInfo.serviceIsStageless || !gitlabMetricsConfig.useEnvironmentStages then
      {}
    else
      { stage: '$stage' };

  local environmentStageSelectorHash = environmentSelectorHash + stageLabels;
  local selectorHash = environmentStageSelectorHash { type: type };

  local dashboard =
    basic.dashboard(
      title,
      uid=uid,
      tags=['gitlab', 'type:' + type, type, 'service overview'],
      includeEnvironmentTemplate=std.objectHas(environmentStageSelectorHash, 'environment'),
    )
    .addPanels(
      headlineMetricsRow(
        type,
        startRow=startRow,
        metricsCatalogServiceInfo=metricsCatalogServiceInfo,
        selectorHash=selectorHash,
        showSaturationCell=std.length(saturationComponents) > 0
      )
    )
    .addPanels(
      metricsCatalogDashboards.sliMatrixForService(
        title='🔬 Service Level Indicators',
        serviceType=type,
        aggregationSet=aggregationSets.componentSLIs,
        startRow=20,
        selectorHash=selectorHash
      )
    )
    .addPanels(
      metricsCatalogDashboards.autoDetailRows(type, selectorHash, startRow=100)
    )
    .addPanelsIf(
      showProvisioningDetails && metricsCatalogServiceInfo.getProvisioning().vms == true,
      [
        nodeMetrics.nodeMetricsDetailRow(selectorHash) {
          gridPos: {
            x: 0,
            y: 300,
            w: 24,
            h: 1,
          },
        },
      ]
    )
    .addPanelsIf(
      showProvisioningDetails && metricsCatalogServiceInfo.getProvisioning().kubernetes == true,
      [
        row.new(title='☸️ Kubernetes Overview', collapse=true)
        .addPanels(kubeServiceDashboards.deploymentOverview(type, environmentSelectorHash, startRow=1)) +
        { gridPos: { x: 0, y: 400, w: 24, h: 1 } },
      ]
    )
    .addPanelsIf(
      std.length(saturationComponents) > 0,
      [
        // saturationSelector is env + type + stage
        local saturationSelector = saturationEnvironmentSelectorHash + stageLabels + { type: type };
        saturationDetail.saturationDetailPanels(saturationSelector, components=saturationComponents)
        { gridPos: { x: 0, y: 500, w: 24, h: 1 } },
      ]
    );

  // Optionally add the stage variable
  local dashboardWithStage =
    if metricsCatalogServiceInfo.serviceIsStageless || !std.objectHas(environmentStageSelectorHash, 'stage') then
      dashboard
    else
      dashboard.addTemplate(templates.stage);

  dashboardWithStage
  {
    overviewTrailer()::
      self
      .addPanelIf(
        showSystemDiagrams,
        systemDiagramPanel.systemDiagramRowForService(type),
        gridPos={ x: 0, y: 100010 }
      )
      .trailer()
      + {
        links+:
          platformLinks.triage +
          platformLinks.services +
          [
            platformLinks.dynamicLinks(type + ' Detail', 'type:' + type),
            platformLinks.kubenetesDetail(type),
          ],
      },
  };


{
  overview:: overviewDashboard,
}
