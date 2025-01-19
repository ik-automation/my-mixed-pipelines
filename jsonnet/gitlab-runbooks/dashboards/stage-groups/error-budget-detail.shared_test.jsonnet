local stageGroupDashboards = import './stage-group-dashboards.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  testDashboardUidAllDetailsUnique: {
    actual: std.map(function(s) s.key, stages.stageGroupsWithoutNotOwned),
    expectUniqueMappings: function(k) stageGroupDashboards.dashboardUid('detail-%s' % [k]),
  },
})
