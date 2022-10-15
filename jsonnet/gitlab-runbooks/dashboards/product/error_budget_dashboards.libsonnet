local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';
local errorBudgetUtils = import 'stage-groups/error-budget/utils.libsonnet';
local errorBudget = import 'stage-groups/error_budget.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local groupDashboardLink(group) =
  toolingLinks.generateMarkdown([
    toolingLinks.grafana(
      "%(group)s's group dashboard" % group.name,
      toolingLinks.grafanaUid('stage-groups/%s.jsonnet' % group.key),
    ),
  ]);

local normalizeUrl(url) = std.strReplace(url, '_', '-');

local groupHandbookLink = function(group)
  normalizeUrl('https://about.gitlab.com/handbook/product/categories/#%s-group' % group.key);

local errorBudgetPanels(group) =
  local budget = errorBudget(errorBudgetUtils.dynamicRange);
  [
    [
      budget.panels.availabilityStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.availabilityTargetStatPanel(group.key),
    ],
    [
      budget.panels.timeRemainingStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.timeRemainingTargetStatPanel(group.key),
    ],
    [
      budget.panels.timeSpentStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.timeSpentTargetStatPanel(group.key),
    ],
    [
      basic.text(
        title='Extra links',
        content=|||
          - [%(group)s's handbook page](%(handbookLink)s)
          %(groupDashboardLink)s
        ||| % {
          group: group.name,
          groupDashboardLink: groupDashboardLink(group),
          handbookLink: groupHandbookLink(group),
        }
      ),
    ],
  ];

local selectGroups(stage, groups) =
  local setGroups = std.set(groups);
  local validGroups = std.set(
    std.map(
      function(stage) stage.key,
      stages.groupsForStage(stage)
    )
  );

  local invalidGroups = std.setDiff(setGroups, validGroups);
  assert std.length(invalidGroups) == 0 : 'Groups not in %(stage)s: %(groups)s' % {
    groups: std.join(', ', invalidGroups),
    stage: stage,
  };

  std.map(function(groupName) stages.stageGroup(groupName), groups);

local dashboard(stage, groups=null) =
  assert std.type(groups) == 'null' || std.type(groups) == 'array' : 'Invalid groups argument type';

  local budget = errorBudget(errorBudgetUtils.dynamicRange);

  local stageGroups =
    if groups == null then
      stages.groupsForStage(stage)
    else
      selectGroups(stage, groups);

  local basicDashboard = basic.dashboard(
    title='Error Budgets - %s' % stage,
    time_from='now-28d',
    tags=['product performance']
  ).addTemplate(
    prebuiltTemplates.stage
  ).addPanel(
    budget.panels.explanationPanel(stage),
    gridPos={ x: 0, y: (std.length(stageGroups) + 1) * 100, w: 24, h: 6 },
  );

  std.foldl(
    function(d, groupWrapper)
      d.addPanels(
        local group = groupWrapper.group;
        local rowIndex = (groupWrapper.index + 1) * 100;
        local title = "%(group)s's Error Budgets (From ${__from:date:YYYY-MM-DD HHːmm} to ${__to:date:YYYY-MM-DD HHːmm})" % {
          group: group.name,
          range: budget.range,
        };
        layout.splitColumnGrid(errorBudgetPanels(group), startRow=rowIndex, cellHeights=[4, 1.5, 1.5], title=title)
      ),
    std.mapWithIndex(
      function(index, group) { group: group, index: index },
      stageGroups
    ),
    basicDashboard
  );

{
  dashboard: dashboard,
}
