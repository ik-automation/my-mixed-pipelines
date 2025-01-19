local aggregationSets = import './aggregation-sets.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

// These are the aggregation sets to rewrite GitLab.com availability and
// error budgets for stage groups. Add any extra aggregation sets needed here.
local aggregationSetsToRewrite = [
  'componentSLIs',
  'regionalComponentSLIs',
  'nodeComponentSLIs',
  'serviceSLIs',
  'nodeServiceSLIs',
  'regionalServiceSLIs',
  'featureCategorySLIs',
  'serviceComponentStageGroupSLIs',
  'serviceComponentStageGroupSLIs',
  'stageGroupSLIs',
];

// The `sla:gitlab:ratio` is a separate recording we have for GitLab.com's availability
// Add any other series to rewrite here
local seriesToRewrite = ['sla:gitlab:ratio'];

// These are the unix timestamps in ms between which to rewrite metrics
local startTimestamp = 1663279200000;
local endTimeStamp = 1663292160000;

local matcherForMetric(name, selector={}) =
  selectors.serializeHash({ __name__: name } + selector, withBraces=true);

local matchersForAggregationSet(setName) =
  local set = aggregationSets[setName];
  local selector = set.selector;
  local metricNamesToRewrite = set.getAllMetricNames();
  [
    {
      matchers: matcherForMetric(name),
      intervals: [{ mint: startTimestamp, maxt: endTimeStamp }],
    }
    for name in metricNamesToRewrite
  ];

local matchersForAggregationSets =
  std.flatMap(matchersForAggregationSet, aggregationSetsToRewrite);

local matchersForSeries =
  [
    {
      matchers: matcherForMetric(name),
      intervals: [{ mint: startTimestamp, maxt: endTimeStamp }],
    }
    for name in seriesToRewrite
  ];
matchersForAggregationSets + matchersForSeries
