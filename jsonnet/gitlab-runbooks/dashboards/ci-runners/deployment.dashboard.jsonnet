local layout = import 'grafana/layout.libsonnet';

local dashboardFilters = import 'stage-groups/verify-runner/dashboard_filters.libsonnet';
local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';
local deploymentDetails = import 'stage-groups/verify-runner/deployment_details.libsonnet';
local jobGraphs = import 'stage-groups/verify-runner/job_graphs.libsonnet';
local jobQueueGraphs = import 'stage-groups/verify-runner/job_queue_graphs.libsonnet';

dashboardHelpers.dashboard(
  'Deployment overview',
  time_from='now-12h/m',
)
.addTemplate(dashboardFilters.runnerJobFailureReason)
.addOverviewPanels()
.addGrid(
  startRow=2000,
  rowHeight=7,
  panels=[
    jobGraphs.running(['instance']),
    jobGraphs.failures(['instance']),
    jobQueueGraphs.pendingSize,
    deploymentDetails.notes,
  ],
)
.addGrid(
  panels=[
    deploymentDetails.runnerManagersCounter,
  ],
  startRow=3001,
  rowHeight=5,
)
.addPanels(
  layout.splitColumnGrid(
    [
      [deploymentDetails.versions],
      [deploymentDetails.uptime],
    ],
    cellHeights=[7, 1],
    startRow=4001,
    columnWidths=[15, 9],
  )
)
