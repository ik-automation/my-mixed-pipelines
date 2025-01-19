local saturationAlerts = import 'alerts/saturation_alerts.libsonnet';
local saturationResources = import 'servicemetrics/saturation-resources.libsonnet';

{
  [saturationResources[key].grafana_dashboard_uid]:
    saturationAlerts.saturationDashboardForComponent(key)
  for key in std.objectFields(saturationResources)
}
