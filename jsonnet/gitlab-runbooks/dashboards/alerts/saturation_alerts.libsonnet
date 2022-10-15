local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local saturationDetail = import 'gitlab-dashboards/saturation_detail.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local template = grafana.template;
local basic = import 'grafana/basic.libsonnet';
local saturationResources = import 'servicemetrics/saturation-resources.libsonnet';
local serviceHealth = import './gitlab-dashboards/service_health.libsonnet';

local selector = { env: '$environment', type: '$type', stage: '$stage' };

{
  saturationDashboard(
    dashboardTitle,
    component,
    panel,
    helpPanel,
    defaultType
  )::

    basic.dashboard(
      dashboardTitle,
      tags=[
        'alert-target',
        'saturationdetail',
      ],
    )
    .addTemplate(
      template.new(
        'type',
        '$PROMETHEUS_DS',
        'label_values(gitlab_service_ops:rate{environment="$environment"}, type)',
        current=defaultType,
        refresh='load',
        sort=1,
      )
    )
    .addTemplate(templates.stage)
    .addPanel(panel, gridPos={ x: 0, y: 0, h: 20, w: 18 })
    .addPanel(helpPanel, gridPos={ x: 18, y: 0, h: 14, w: 6 })
    .addPanel(serviceHealth.activeAlertsPanel('alert_type="symptom", type="${type}", environment="$environment"', title='Potentially User Impacting Alerts'), gridPos={ x: 18, y: 14, h: 6, w: 6 })
    .trailer()
    + {
      links+: platformLinks.parameterizedServiceLink +
              platformLinks.services +
              platformLinks.triage +
              [
                platformLinks.dynamicLinks('Service Dashboards', 'type:$type managed', asDropdown=false, includeVars=false, keepTime=false),
                platformLinks.dynamicLinks('Saturation Detail', 'saturationdetail', asDropdown=true, includeVars=true, keepTime=true),
              ],
    },

  saturationDashboardForComponent(
    component
  )::
    local defaultType = saturationResources[component].getDefaultGrafanaType();

    self.saturationDashboard(
      dashboardTitle=component + ': Saturation Detail',
      component=component,
      panel=saturationDetail.componentSaturationPanel(component, selector),
      helpPanel=saturationDetail.componentSaturationHelpPanel(component),
      defaultType=defaultType
    ),
}
