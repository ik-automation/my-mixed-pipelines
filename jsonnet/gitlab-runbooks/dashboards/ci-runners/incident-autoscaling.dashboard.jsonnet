local autoscalingGraphs = import 'stage-groups/verify-runner/autoscaling_graphs.libsonnet';
local dashboardFilters = import 'stage-groups/verify-runner/dashboard_filters.libsonnet';
local dashboardIncident = import 'stage-groups/verify-runner/dashboard_incident.libsonnet';

dashboardIncident.incidentDashboard(
  'autoscaling',
  'as',
  description=|||
    In short: problems with autoscaling will reduce (even totally) the capacity of our Runners.

    **It's recommended to review the graphs after limiting the shard variable to only
    the part of Runners that we want to analyse.** Otherwise the number of different lines
    may be overwhelming. Please also remember that **different shards have different autosacling
    settings**, where the `shared` one is the most outstanding at it creates a VM dedicated for
    every job and removes it just after the job is finished.

    Known problem indicators:
    - high number of VMs in `creating` state for a longer period,
    - unnatural shape of the `creating` state VMs line,
    - `idle` VMs value constantly near `0`,
    - VM operations going up-and-down in a sinewave-like shape,
    - VMs creation timing increased above the usual average,
    - exceeding GCP quotas.

    Autoscaling problems are usually caused by three possible reasons:
    - Exceeding GCP quotas (especially the API ones). For that go to the GCP console
      to projects where autoscaled VMs are created for the shard (note that we're currently
      spliting shards between multiple projects **so this needs to be checked in all of them**)
      and check if we're not exceeding the API quotas. Especially the `read requests` and
      `operation read requests`.
    - Bug in configuration of autoscaling. Wrong configuration may effect with Docker Machine not
      being able to create the VM or VM being not accessible after it was created. Double check
      if there were any changes made in Runner Manager's `config.toml` file, in the `[docker.machine]`
      section.
    - Docker Machine bug. Very rare, as we've probably already caught all of them, but to be sure
      check if there was no updates of used Docker Machine version just before the incideent happened.
  |||,
)
.addTemplates([
  dashboardFilters.gcpExporter,
  dashboardFilters.gcpProject,
  dashboardFilters.gcpRegion,
])
.addGrid(
  panels=[
    autoscalingGraphs.vmStates,
    autoscalingGraphs.vmOperationsRate,
    autoscalingGraphs.vmCreationTiming,
  ],
  rowHeight=8,
  startRow=3000,
)
.addGrid(
  panels=[
    autoscalingGraphs.gcpRegionQuotas,
    autoscalingGraphs.gcpInstances,
  ],
  rowHeight=8,
  startRow=4000,
)
