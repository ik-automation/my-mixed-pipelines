local basic = import './basic.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local row = grafana.row;

local testStableIdDashboard =
  basic.dashboard('Test', [])
  .addPanels([
    basic.graphPanel('TEST', stableId='test-graph-panel'),
  ])
  .addPanel(
    row.new(title='Row', collapse=true)
    .addPanels([
      basic.graphPanel('TEST', stableId='collapsed-panel'),
    ]),
    gridPos={
      x: 0,
      y: 500,
      w: 24,
      h: 1,
    }
  )
  .trailer();

test.suite({
  testStableIds: {
    actual: testStableIdDashboard,
    expectThat: function(dashboard) dashboard.panels[0].id == 162106516,  // stableId for test-graph-panel
  },
  testNestedStableIds: {
    actual: testStableIdDashboard,
    expectThat: function(dashboard) dashboard.panels[1].panels[0].id == 3457099265,  // stableId for collapsed-panel
  },
})
