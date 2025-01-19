local dashboardFilters = import './dashboard_filters.libsonnet';
local dashboardHelpers = import './dashboard_helpers.libsonnet';
local jobGraphs = import './job_graphs.libsonnet';
local jobQueueGraphs = import './job_queue_graphs.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

local incidentDashboard(incidentType, incidentTypeTag, description=null) =
  local descriptionPanel = if description != null then
    [
      grafana.text.new(
        title='%s caused incident notes' % incidentType,
        mode='markdown',
        content=description,
      ),
    ]
  else
    [];

  local commonPanels = [
    jobGraphs.running(['shard']),
    jobGraphs.started(['shard']),
    jobQueueGraphs.durationHistogram,
    jobQueueGraphs.pendingSize,
  ] + descriptionPanel;

  dashboardHelpers.dashboard(
    'Incident Support: %s' % incidentType,
    tags=[
      '%s:incident-support' % dashboardHelpers.runnerServiceType,
      '%(serviceType)s:incident-%(incidentType)s' % {
        serviceType: dashboardHelpers.runnerServiceType,
        incidentType: incidentTypeTag,
      },
    ]
  )
  .addTemplates([
    dashboardFilters.jobsRunningForProject,
  ])
  .addOverviewPanels(
    compact=false,
    showOpsRate=true,
    rowHeight=7,
    startRow=0,
  )
  .addGrid(
    panels=commonPanels,
    rowHeight=7,
    startRow=1000,
  );

{
  incidentDashboard:: incidentDashboard,
}
