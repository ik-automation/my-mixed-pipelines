// Sidekiq Shard Definitions
// This should contain a list of sidekiq shards
//
// NOTE: while we transition to k8s, this list needs to be kept
// in sync with two other sources:
// 1. SHARD_CONFIGURATIONS: https://ops.gitlab.net/gitlab-cookbooks/chef-repo/-/blob/master/tools/sidekiq-config/sidekiq-queue-configurations.libsonnet
// 2. Helm Configuration:
//    a. https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/gitlab-com/-/blob/master/releases/gitlab/values/values.yaml.gotmpl
//    b. https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/gitlab-com/-/blob/master/releases/gitlab/values/gprd.yaml.gotmpl
//
// To avoid even more complication, this list should remain the SSOT for the runbooks project if at all possible!
local shardDefaults = {
  monitoringThresholds: {},  // By default fall back to the service thresholds
  autoScaling: true,  // Only throttled shards don't autoscale
};

local shardDefinitions = {
  'database-throttled': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-database-throttled-v1', userImpacting: false, trafficCessationAlertConfig: false },
  'gitaly-throttled': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-gitaly-throttled-v1', userImpacting: false, trafficCessationAlertConfig: false },
  imports: { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-v1', userImpacting: true, trafficCessationAlertConfig: false, autoScaling: false },
  'low-urgency-cpu-bound': { urgency: 'low', gkeDeployment: 'gitlab-sidekiq-low-urgency-cpu-bound-v1', userImpacting: true, trafficCessationAlertConfig: true },
  'memory-bound': {
    urgency: null,
    gkeDeployment: 'gitlab-sidekiq-memory-bound-v1',
    userImpacting: true,
    trafficCessationAlertConfig: false,
    monitoringThresholds+: {
      apdexScore: 0.92,
    },
  },
  quarantine: { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-v1', userImpacting: true, trafficCessationAlertConfig: false },
  'urgent-cpu-bound': { urgency: 'high', gkeDeployment: 'gitlab-sidekiq-urgent-cpu-bound-v1', userImpacting: true, trafficCessationAlertConfig: true },
  'urgent-other': { urgency: 'high', autoScaling: false, gkeDeployment: 'gitlab-sidekiq-urgent-other-v1', userImpacting: true, trafficCessationAlertConfig: true },
  'urgent-authorized-projects': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-urgent-authorized-projects-v1', userImpacting: true, trafficCessationAlertConfig: false },
  catchall: { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-v1', userImpacting: true, trafficCessationAlertConfig: true /* no urgency attribute since multiple values are supported */ },
  elasticsearch: { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-elasticsearch-v1', userImpacting: false, trafficCessationAlertConfig: false },
};

local shards = std.foldl(
  function(memo, shardName)
    memo { [shardName]: shardDefaults + shardDefinitions[shardName] { name: shardName } },
  std.objectFields(shardDefinitions),
  {}
);
// These values are used in several places, so best to DRY them up
{
  slos: {
    urgent: {
      queueingDurationSeconds: 10,
      executionDurationSeconds: 10,
    },
    lowUrgency: {
      queueingDurationSeconds: 60,
      executionDurationSeconds: 300,
    },
    throttled: {
      // Throttled jobs don't have a queuing duration,
      // so don't add one here!
      executionDurationSeconds: 300,
    },
  },
  shards: {
    listByName():: std.objectFields(shards),

    listAll():: std.objectValues(shards),

    // List shards which match on the supplied predicate
    listFiltered(filterPredicate): std.filter(function(f) filterPredicate(shards[f]), std.objectFields(shards)),
  },
}
