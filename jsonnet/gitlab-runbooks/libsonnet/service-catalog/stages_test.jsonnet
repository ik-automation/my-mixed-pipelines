local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';

test.suite({
  testBlank: {
    actual: stages.findStageGroupForFeatureCategory('users').name,
    expect: 'Workspace',
  },
  testNotOwnedStageGroupForFeatureCategory: {
    actual: stages.findStageGroupForFeatureCategory('not_owned').name,
    expect: 'not_owned',
  },
  testNotOwnedStageGroupNameForFeatureCategory: {
    actual: stages.findStageGroupNameForFeatureCategory('not_owned'),
    expect: 'not_owned',
  },
  testNotOwnedStageNameForFeatureCategory: {
    actual: stages.findStageNameForFeatureCategory('not_owned'),
    expect: 'not_owned',
  },
  testStageGroupAddsKey: {
    actual: stages.stageGroup('authentication_and_authorization').key,
    expect: 'authentication_and_authorization',
  },
  testStageGroupAddsTeam: {
    actual: stages.stageGroup('authentication_and_authorization').slack_alerts_channel,
    expect: 'feed_alerts_access',
  },
  testFeatureCategoryMapCategories: {
    actual: std.objectFields(stages.featureCategoryMap),
    expectThat: {
      knownCategories: std.set(['source_code_management', 'code_review']),
      result:
        local intersection = std.setInter(self.knownCategories, self.actual);
        intersection == self.knownCategories,
      description: 'did not contain known categories: %s' % std.toString(self.knownCategories),
    },
  },
  testFeatureCategoryMapGroup: {
    // The feature category 'source_code_management' is owned by the 'source_code' group
    actual: stages.featureCategoryMap.source_code_management,
    expect: stages.stageGroup('source_code'),
  },
})
