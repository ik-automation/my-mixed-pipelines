local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local aggregationSetTransformer = import 'servicemetrics/aggregation-set-transformer.libsonnet';
local applicationSlis = (import 'gitlab-slis/library.libsonnet').all;
local applicationSliAggregations = import 'gitlab-slis/aggregation-sets.libsonnet';

local defaultsForRecordingRuleGroup = { partial_response_strategy: 'warn' };

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

local groupsForApplicationSli(sli) =
  local targetAggregationSet = applicationSliAggregations.targetAggregationSet(sli);
  local sourceAggregationSet = applicationSliAggregations.sourceAggregationSet(sli);
  aggregationSetTransformer.generateRecordingRuleGroups(
    sourceAggregationSet=sourceAggregationSet,
    targetAggregationSet=targetAggregationSet,
    extrasForGroup=defaultsForRecordingRuleGroup
  );


/**
 * This file defines all the aggregation recording rules that will aggregate in Thanos to a single global view
 */
{
  /**
   * Aggregates from multiple "split-brain" prometheus SLIs to a global/single-view SLI metrics
   */
  'aggregated-component-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceSLIs,
        targetAggregationSet=aggregationSets.componentSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup

      )
    ),

  /**
   * Aggregates from multiple "split-brain" prometheus SLIs to a global/single-view service-level aggregated metrics
   */
  'aggregated-service-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceSLIs,
        targetAggregationSet=aggregationSets.serviceSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup
      )
    ),

  /**
   * Aggregates from multiple "split-brain" prometheus per-node SLIs to a global/single-view SLI-node-level aggregated metrics
   */
  'aggregated-sli-node-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceNodeComponentSLIs,
        targetAggregationSet=aggregationSets.nodeComponentSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup
      ),
    ),

  /**
   * Aggregates from multiple "split-brain" prometheus SLIs to a global/single-view service-node-level aggregated metrics
   * TODO: consider whether this aggregation is neccessary and useful.
   */
  'aggregated-service-node-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceNodeComponentSLIs,
        targetAggregationSet=aggregationSets.nodeServiceSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup
      ),
    ),

  /**
   * Regional SLIS
   */
  'aggregated-sli-regional-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceSLIs,
        targetAggregationSet=aggregationSets.regionalComponentSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup

      ),
    ),

  /**
   * Regional SLIs, aggregated to the service level
   */
  'aggregated-service-regional-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.promSourceSLIs,
        targetAggregationSet=aggregationSets.regionalServiceSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup

      ),
    ),

  'aggregated-feature-category-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.featureCategorySourceSLIs,
        targetAggregationSet=aggregationSets.featureCategorySLIs,
        extrasForGroup=defaultsForRecordingRuleGroup

      ),
    ),

  'aggregated-service-component-stage-group-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.featureCategorySourceSLIs,
        targetAggregationSet=aggregationSets.serviceComponentStageGroupSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup

      ),
    ),

  'aggregated-stage-group-metrics.yml':
    outputPromYaml(
      aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSets.featureCategorySourceSLIs,
        targetAggregationSet=aggregationSets.stageGroupSLIs,
        extrasForGroup=defaultsForRecordingRuleGroup
      ),
    ),

  // Application SLIs not used in the service catalog  will be aggregated here.
  // These aggregations allow us to see what the metrics look like before adding
  // an them, so we can validate they would not trigger alerts.
  // If the application SLI is added to the service catalog, it will automatically
  // generate `sli_aggregation:` recordings that can be reused everywhere. So no
  // real need to duplicate them.
  'aggregated-application-sli-metrics.yml':
    outputPromYaml(
      std.flatMap(
        groupsForApplicationSli,
        applicationSlis
      ),
    ),
}
