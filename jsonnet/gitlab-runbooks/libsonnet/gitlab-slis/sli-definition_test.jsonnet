local sliDefinition = import './sli-definition.libsonnet';
local test = import 'test.libsonnet';
local objects = import 'utils/objects.libsonnet';

local validDefinition = {
  name: 'hello_sli',
  kinds: [sliDefinition.apdexKind],
  description: 'an SLI counting hellos',
  significantLabels: ['world'],
  featureCategory: 'error_budgets',
};

test.suite({
  testNew: {
    actual: sliDefinition.new(validDefinition),
    expectContains: {
      name: 'hello_sli',
      kinds: [sliDefinition.apdexKind],
      featureCategory: 'error_budgets',
      description: 'an SLI counting hellos',
      significantLabels: ['world'],
      inRecordingRuleRegistry: false,
      totalCounterName: 'gitlab_sli_hello_sli_apdex_total',
      apdexTotalCounterName: 'gitlab_sli_hello_sli_apdex_total',
      apdexSuccessCounterName: 'gitlab_sli_hello_sli_apdex_success_total',
      recordingRuleMetrics: [
        'gitlab_sli_hello_sli_apdex_total',
        'gitlab_sli_hello_sli_apdex_success_total',
      ],
    },
  },

  testNewWithoutFeatureCategory: {
    local definitionWithoutFeatureCategory = objects.objectWithout(validDefinition, 'featureCategory') {
      significantLabels: ['world', 'feature_category'],
    },
    actual: sliDefinition.new(definitionWithoutFeatureCategory),
    expectContains: {
      featureCategory: 'featureCategoryFromSourceMetrics',
      significantLabels: ['world', 'feature_category'],
    },
  },

  testNewMultipleKinds: {
    actual: sliDefinition.new(validDefinition {
      kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    }),
    expectContains: {
      kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
      totalCounterName: 'gitlab_sli_hello_sli_total',
      apdexTotalCounterName: 'gitlab_sli_hello_sli_apdex_total',
      apdexSuccessCounterName: 'gitlab_sli_hello_sli_apdex_success_total',
      errorTotalCounterName: 'gitlab_sli_hello_sli_total',
      errorCounterName: 'gitlab_sli_hello_sli_error_total',
      recordingRuleMetrics: [
        'gitlab_sli_hello_sli_apdex_total',
        'gitlab_sli_hello_sli_apdex_success_total',
        'gitlab_sli_hello_sli_total',
        'gitlab_sli_hello_sli_error_total',
      ],
    },
  },

  local validSLI = sliDefinition._applyDefaults(validDefinition),
  testValidateFeatureCategoryUnknown: {
    local sli = validSLI { featureCategory: 'not a feature' },
    actual: sli,
    expectMatchingValidationError: {
      validator: sliDefinition._sliValidator,
      message: 'field featureCategory',
    },
  },

  testValdidateFeatureCategoryNotOwned: {
    local sli = validSLI { featureCategory: 'not_owned' },
    actual: sli,
    expectValid: sliDefinition._sliValidator,
  },

  testValidateFeatureCategoryNull: {
    local sli = validSLI { featureCategory: null },
    actual: sli,
    expectMatchingValidationError: {
      validator: sliDefinition._sliValidator,
      message: 'field featureCategory',
    },
  },

  testValidateFeatureCategoryMissing: {
    local sli = objects.objectWithout(validSLI, 'featureCategory'),
    actual: sli,
    expectMatchingValidationError: {
      validator: sliDefinition._sliValidator,
      message: 'field featureCategory',
    },
  },

  testValidateInvalidKind: {
    actual: validSLI { kinds: ['foo_rate'] },
    expectMatchingValidationError: {
      validator: sliDefinition._sliValidator,
      message: 'field kinds',
    },
  },

  testValidateNoKind: {
    actual: validSLI { kinds: [] },
    expectMatchingValidationError: {
      validator: sliDefinition._sliValidator,
      message: 'field kinds',
    },
  },
})
