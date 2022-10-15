local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local serviceCatalog = metricsConfig.serviceCatalog;
local allServices = metricsConfig.monitoredServices;
local stageGroupMapping = metricsConfig.stageGroupMapping;
local miscUtils = import 'utils/misc.libsonnet';

local serviceMap = {
  [x.name]: x
  for x in serviceCatalog.services
};

local teamDefaults = {
  issue_tracker: null,
  send_slo_alerts_to_team_slack_channel: false,
  ignored_components: [],
};

local teamMap = std.foldl(
  function(result, team)
    assert !std.objectHas(result, team.name) : 'Duplicate definition for team: %s' % [team.name];
    result { [team.name]: teamDefaults + team },
  serviceCatalog.teams,
  {}
);

local teamGroupMap = std.foldl(
  function(result, team)
    if std.objectHas(team, 'product_stage_group') && team.product_stage_group != null then
      assert std.objectHas(stageGroupMapping, team.product_stage_group) : 'team %s has an unknown stage group %s' % [team.name, team.product_stage_group];
      assert !std.objectHas(result, team.product_stage_group) : 'team %s already has a team with stage group %s' % [team.name, team.product_stage_group];
      result { [team.product_stage_group]: team }
    else
      result,
  std.objectValues(teamMap),
  {}
);

local buildServiceGraph(services) =
  std.foldl(
    function(graph, service)
      local dependencies =
        if std.objectHas(service, 'serviceDependencies') then
          miscUtils.arrayDiff(std.objectFields(service.serviceDependencies), [service.type])
        else
          [];
      if std.length(dependencies) > 0 then
        graph + {
          [dependency]: {
            inward: std.uniq([service.type] + graph[dependency].inward),
            outward: graph[dependency].outward,
          }
          for dependency in dependencies
        } + {
          [service.type]: {
            inward: graph[service.type].inward,
            outward: std.uniq(dependencies + graph[service.type].outward),
          },
        }
      else
        graph,
    services,
    std.foldl(
      function(graph, service) graph { [service.type]: { inward: [], outward: [] } },
      services,
      {}
    )
  );

{
  lookupService(name)::
    if std.objectHas(serviceMap, name) then serviceMap[name],

  buildServiceGraph: buildServiceGraph,
  serviceGraph:: buildServiceGraph(allServices),

  getTeams()::
    std.objectValues(teamMap),

  lookupTeamForStageGroup(name)::
    if std.objectHas(teamGroupMap, name) then teamGroupMap[name] else teamDefaults,

  getTeam(teamName)::
    teamMap[teamName],

  findServices(filterFunc)::
    std.filter(filterFunc, serviceCatalog.services),

  findKeyBusinessServices(includeZeroScore=false)::
    std.filter(
      function(service)
        std.objectHas(service, 'business') &&
        std.objectHas(service.business.SLA, 'overall_sla_weighting') &&
        (if includeZeroScore then service.business.SLA.overall_sla_weighting >= 0 else service.business.SLA.overall_sla_weighting > 0),
      serviceCatalog.services
    ),
}
