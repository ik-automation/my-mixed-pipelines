local sidekiqPerWorkerRecordingRules = import '../metrics-catalog/services/lib/sidekiq-per-worker-recording-rules.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
// This file redefines the SLIs to use per worker rules to use for the feature
// category aggregation instead of relying on the actual SLIs defined on the service.
// This will be changed as part of https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/700
{
  'custom-feature-category-metrics-sidekiq.yml': std.manifestYamlDoc({
    groups: [{
      name: 'Prometheus Intermediate Metrics per feature',
      interval: '1m',
      rules: sidekiqPerWorkerRecordingRules.perWorkerRecordingRulesForAggregationSet(aggregationSets.featureCategorySourceSLIs, { component: 'sidekiq_execution' }),
    }],
  }),
}
