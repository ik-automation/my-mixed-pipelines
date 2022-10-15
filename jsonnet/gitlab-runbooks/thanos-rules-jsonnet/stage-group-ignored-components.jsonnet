local stages = import 'service-catalog/stages.libsonnet';

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

local ruleGroupForStageGroup(stageGroup) = {
  name: 'Stage group Ignored components: %s - %s' % [stageGroup.stage, stageGroup.name],
  partial_response_strategy: 'warn',
  interval: '1m',
  rules: [
    {
      record: 'gitlab:ignored_component:stage_group',
      labels: {
        product_stage: stageGroup.stage,
        stage_group: stageGroup.key,
        component: ignoredComponent,
      },
      expr: '1',
    }
    for ignoredComponent in stageGroup.ignored_components
  ],
};

{
  'stage-group-ignored-components.yml':
    outputPromYaml(
      std.filterMap(
        function(group) std.length(group.ignored_components) > 0,
        ruleGroupForStageGroup,
        stages.stageGroups
      )
    ),
}
