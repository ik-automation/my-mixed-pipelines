local capacityReviewDashboards = import './capacity_review_dashboard.libsonnet';
local kubeDashboards = import './kube_service_dashboards.libsonnet';
local regionalDashboards = import './regional_service_dashboard.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;

local forService(serviceType) =
  local serviceInfo = metricsCatalog.getService(serviceType);

  {}
  +
  (
    if serviceInfo.regional then
      {
        regional: regionalDashboards.dashboardForService(
          serviceType,
          serviceSLIsAggregationSet=aggregationSets.regionalServiceSLIs,
          componentSLIsAggregationSet=aggregationSets.regionalComponentSLIs,
        ),
      }
    else
      {}
  )
  +
  (
    if std.length(serviceInfo.kubeResources) > 0 then
      kubeDashboards.dashboardsForService(serviceType)
    else
      {}
  )
  +
  capacityReviewDashboards.dashboardsForService(serviceType);

{
  forService:: forService,
}
