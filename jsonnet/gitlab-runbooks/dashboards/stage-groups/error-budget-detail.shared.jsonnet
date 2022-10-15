local stageGroupDashboards = import '../stage-groups/stage-group-dashboards.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';

std.foldl(
  function(memo, stageGroup)
    local uid = stageGroupDashboards.dashboardUid('detail-%s' % [stageGroup.key]);

    memo {
      [uid]: stageGroupDashboards.errorBudgetDetailDashboard(stageGroup),
    },
  // To test on a subset of stages, do something like:
  // stages.groupsForStage('manage'),
  // or
  // std.map(stages.stageGroup, ['global_search', 'package', 'workspace']),
  stages.stageGroupsWithoutNotOwned,
  {}
)
