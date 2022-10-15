local stages = import 'service-catalog/stages.libsonnet';

local rules = std.map(
  function(featureCategory)
    local stageGroup = stages.featureCategoryMap[featureCategory];
    {
      record: 'gitlab:feature_category:stage_group:mapping',
      labels: {
        feature_category: featureCategory,
        stage_group: stageGroup.key,
        product_stage: stageGroup.stage,
      },
      expr: '1',
    },
  std.objectFields(stages.featureCategoryMap)
);

{
  mappingYaml(extrasForGroup={}): {
    'stage-group-feature-category-mapping-rules.yml': std.manifestYamlDoc({
      groups: [{
        name: 'Feature Category Stage group mapping',
        rules: rules,
        interval: '1m',
      } + extrasForGroup],
    }),
  },
}
