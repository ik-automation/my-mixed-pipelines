local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local link = grafana.link;
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';

local GRAFANA_BASE_URL = 'https://dashboards.gitlab.net/d/';

// These services do not yet have their own dashboards, remove from this list as they get their own dashboards
local USES_GENERIC_DASHBOARD = {
  pages: true,
};

local getServiceLink(serviceType) =
  if std.objectHas(USES_GENERIC_DASHBOARD, serviceType) then
    'https://dashboards.gitlab.net/d/general-service/service-platform-metrics?orgId=1&var-type=' + serviceType
  else
    GRAFANA_BASE_URL + serviceCatalog.lookupService(serviceType).observability.monitors.primary_grafana_dashboard + '?orgId=1';

{
  triage:: [
    link.dashboards('Platform Triage', '', type='link', keepTime=true, url='https://dashboards.gitlab.net/d/general-triage/platform-triage?orgId=1'),
  ],
  services:: [
    link.dashboards(
      title='Service Overview Dashboards',
      tags=[
        'managed',
        'service overview',
      ],
      asDropdown=true,
      includeVars=true,
      keepTime=true,
      type='dashboards',
    ),
  ],
  backToOverview(type)::
    link.dashboards('🔙 Back to ' + type + ' service', '', type='link', keepTime=true, url=getServiceLink(type)),

  kubenetesDetail(type)::
    link.dashboards(
      title='☸️ %s Kubernetes Detail' % [type],
      tags=[
        'managed',
        'type:' + type,
        'kube detail',
      ],
      asDropdown=true,
      includeVars=true,
      keepTime=true,
      type='dashboards',
    ),
  parameterizedServiceLink: [
    link.dashboards('$type service', '', type='link', keepTime=true, url='https://dashboards.gitlab.net/d/general-service/service-platform-metrics?orgId=1&var-type=$type'),
  ],
  serviceLink(type):: [
    link.dashboards(type + ' service', '', type='link', keepTime=true, url=getServiceLink(type)),
  ],
  dynamicLinks(title, tags, asDropdown=true, icon='dashboard', includeVars=true, keepTime=true)::
    link.dashboards(
      title,
      tags,
      asDropdown=asDropdown,
      includeVars=includeVars,
      keepTime=keepTime,
      icon=icon,
    ),
}
