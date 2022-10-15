local ciBuildsQueueGraphs = import 'stage-groups/verify-continuous-integration/builds_queue_graphs.libsonnet';
local ciDashboardFilters = import 'stage-groups/verify-continuous-integration/dashboard_filters.libsonnet';
local dashboardFilters = import 'stage-groups/verify-runner/dashboard_filters.libsonnet';
local dashboardIncident = import 'stage-groups/verify-runner/dashboard_incident.libsonnet';
local databaseGraphs = import 'stage-groups/verify-runner/database_graphs.libsonnet';

dashboardIncident.incidentDashboard(
  'database',
  'db',
  description=|||
    In short: scheduling of CI/CD jobs to runners fully depends on DB. Any DB problems may affect our ability
    to pass jobs to runners that are asking for them.

    The scheduling is done by using a special SQL query executed on API requests to `/api/v4/jobs/request`. We name
    this query "Big Query". Depending on the type of the runner that asks for a job (instance, group or project)
    the query is slightly different. The query for `instance_type` runners is most complicated and execution heavy,
    as it includes resolving the "fair scheduling algorithm" problem, respecting Pipeline Minutes quotas and checking
    if `instance_type` runners are even enabled for a project.

    The query does also initial handling of runner tags matching.

    The result is next filtered in Rails to fully resolve tags matching, respect the `protected` setting etc. From the
    final list of jobs GitLab tries to schedule the first one to the Runner that asked for a job. In case the same
    job was already assigned to another Runner that asked for a job concurrently, GitLab tries - but only once - to
    schedule the second job from the list. If this also fails on SQL transaction (which mostly means that this job also
    was already scheduled to a different Runner by a different request) the `409 Conflict` response is sent back.

    The Big Query should be executed only on the read-only replicas.

    Known problem indicators:
    - general Patroni service problems,
    - a high number of dead tuples for tables used in the Big Query,
    - a high percentage of dead tuples for tables used in the Big Query,
    - a high number of slow queries on the replicas (usually >50 opm becomes problematic).

    Database problems can be caused by many different reasons and it's hard to define "most known problems".
    However, the most popular ones that we've seen regularly are:
    - A significant increase of jobs in the `pending` queue, which makes executions of queries on `ci_builds` much
      slower.
    - A significant increase of requests to `/api/v4/jobs/request` which triggers more Big Query executions and may
      be the source of DB slowness.
    - VACUUM or AUTOVACUUM running on the DB (especially on the tables used in the Big Query).
    - Long running transactions (for example sourced by DB migrations) that are blocking DB and causing slower
      queries execution.
  |||,
)
.addTemplates([
  dashboardFilters.dbInstance,
  dashboardFilters.dbInstances,
  dashboardFilters.dbDatabase,
  dashboardFilters.dbTopDeadTuples,
  ciDashboardFilters.runnerTypeTemplate(hide=''),
])
.addPanels(
  databaseGraphs.patroniOverview(
    startRow=2000,
    rowHeight=6,
  )
)
.addGrid(
  panels=[
    databaseGraphs.totalDeadTuples,
    databaseGraphs.deadTuplesPercentage,
    databaseGraphs.slowQueries,
  ],
  startRow=3000,
  rowHeight=8,
)
.addGrid(
  panels=[
    ciBuildsQueueGraphs.bigQueryDuration(percentiles=[50, 90, 95, 99]),
  ],
  startRow=4000,
  rowHeight=8,
)
