local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local apiGraphs = import 'stage-groups/verify-runner/api_graphs.libsonnet';
local dashboardIncident = import 'stage-groups/verify-runner/dashboard_incident.libsonnet';
local sidekiqGraphs = import 'stage-groups/verify-runner/sidekiq_graphs.libsonnet';
local workhorseGraphs = import 'stage-groups/verify-runner/workhorse_graphs.libsonnet';

dashboardIncident.incidentDashboard(
  'gitlab-application',
  'gl-app',
  description=|||
    Most logic of how pipelines and jobs are being handled is happening in GitLab. Runner is the last
    element of the chain - it asks for a job and receives the payload **if any job was scheduled by GitLab
    for that Runner**.

    **Please remember: It's Runner that asks for jobs. It's Runner that sends back the responses. Apart of
    CI Web Terminal feature (which we haven't configured on our runners fleet) the communicatation always
    goes in this direction - from Runner to GitLab.**

    Therefore Runners are vulnerable for any problems happening on GitLab side, whether these are problem with
    API (that Runner uses to talk with GitLab), problems with skidekiq (which is used to handle many background
    taksks related to pipelines and jobs handling) or queueing and long polling that we've implemented in
    GitLab Workhose.

    Known problem indicators:
    - increased number of 5xx errors observed by Runner for some requests that they are doing against GitLab's API,
    - increased size of pipeline.* queues in sidekiq,
    - general load increase on API nodes,
    - misbehavior of workhorse long polling,
    - increased timing of workhorse queueing.

    GitLab Application problems affecting Runners are usually caused by three reasons:
    - Database slowness that affects every part of the application stack. You can double check this with the dedicated
      dashboard: open the `ci-runners Incident Dashboards` list and select `ci-runners: Incident Support: database`.
      If the database is slow, then this should be our main concern and efforts should be shifted there.

      Please note that the `/api/v4/jobs/request` endpoint is known of being the main cause of database problems
      when it goes for CI (the size of `ci_builds` and complexity of jobs scheduling query is enormous) and usually the
      main victim of such slowness in the CI area. There is an ongoing work on fixing this part.

    - Sidekiq problems. Any Sidekiq problems that affect the time of processing of `pipeline.*` queues may affect the
      affect the user experience, especially when it goes for transitioning jobs and pipelines between different states.
      If Sidekiq metrics for `pipeline.*` look strange, double check that we don't have load problem on the sidekiq nodes
      nor that there are no problems with Redis.

    - Workhorse polling and queueing problems. All requests made by Runner are going through GitLab Workhorse. For the
      most important endpoint - `POST /api/v4/jobs/request` - we've implemented a long polling mechanism that reduces
      the amount of requests created by Runners. All the requests can be also queued on the Workhorse level if Rails
      is slow in handling them. Therefore any misconfiguration here may lead to problems with requests handling. Double
      check that there was no changes in Workhorse configuration or Workhorse itself if there are any problems observed
      on the Workhorse graphs.
  |||,
)
.addGrid(
  panels=[
    apiGraphs.runnerRequests('request_job'),
    apiGraphs.runnerRequests('update_job'),
    apiGraphs.runnerRequests('patch_trace'),
  ],
  startRow=3000,
  rowHeight=6,
)
.addGrid(
  panels=[
    apiGraphs.runnerRequests('request_job', '(4|5)..'),
    apiGraphs.runnerRequests('update_job', '(4|5)..'),
    apiGraphs.runnerRequests('patch_trace', '(4|5)..'),
  ],
  startRow=4000,
  rowHeight=6,
)
.addGrid(
  panels=[
    sidekiqGraphs.pipelineQueues,
    nodeMetrics.nodeLoadForDuration(duration=5, nodeSelector='environment="$environment", stage="$stage", type="api"'),
    apiGraphs.jobRequestsOnWorkhorse,
  ],
  startRow=5000,
  rowHeight=8,
)
.addGrid(
  panels=[
    workhorseGraphs.longPollingRequestStateCounter,
    workhorseGraphs.longPollingOpenRequests,
    workhorseGraphs.queueingErrors,
  ],
  startRow=6000,
  rowHeight=8,
)
.addGrid(
  panels=[
    workhorseGraphs.queueingHandledRequests,
    workhorseGraphs.queueingQueuedRequests,
    workhorseGraphs.queueingTime,
  ],
  startRow=7000,
  rowHeight=8,
)
