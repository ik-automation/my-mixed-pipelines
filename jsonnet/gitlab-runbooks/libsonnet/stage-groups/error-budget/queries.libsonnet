local utils = import './utils.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local labels = import 'promql/labels.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local durationParser = import 'utils/duration-parser.libsonnet';
local strings = import 'utils/strings.libsonnet';

local ignoredComponentJoinLabels = ['stage_group', 'component'];
local ignoreCondition(ignoreComponents) =
  if ignoreComponents then
    'unless on (%s) gitlab:ignored_component:stage_group' % [aggregations.serialize(ignoredComponentJoinLabels)]
  else
    '';

local errorBudgetRatio(range, groupSelectors, aggregationLabels, ignoreComponents) =
  |||
    clamp_max(
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          label_replace(
            sum_over_time(
              gitlab:component:stage_group:execution:apdex:success:rate_1h{%(selectorHash)s}[%(range)s]
            ), 'sli_kind', 'apdex', '', ''
          )
          or
          label_replace(
            sum_over_time(
              gitlab:component:stage_group:execution:ops:rate_1h{%(selectorHash)s}[%(range)s]
            )
            -
            sum_over_time(
              gitlab:component:stage_group:execution:error:rate_1h{%(selectorHash)s}[%(range)s]
            ), 'sli_kind', 'error', '', ''
          )
        ) %(ignoreCondition)s
      )
      /
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          label_replace(
            sum_over_time(
              gitlab:component:stage_group:execution:apdex:weight:score_1h{%(selectorHash)s}[%(range)s]
            ),
            'sli_kind', 'apdex', '', ''
          )
          or
          label_replace(
            sum_over_time(
              gitlab:component:stage_group:execution:ops:rate_1h{%(selectorHash)s}[%(range)s]
            )
            and sum_over_time(gitlab:component:stage_group:execution:error:rate_1h{%(selectorHash)s}[%(range)s]),
            'sli_kind', 'error', '', ''
          )
        ) %(ignoreCondition)s
      ),
    1)
  ||| % {
    selectorHash: selectors.serializeHash(groupSelectors),
    range: range,
    aggregations: aggregations.serialize(aggregationLabels),
    aggregationsIncludingComponent: aggregations.serialize(aggregationLabels + ignoredComponentJoinLabels),
    ignoreCondition: ignoreCondition(ignoreComponents),
  };

local errorBudgetTimeSpent(range, selectors, aggregationLabels, ignoreComponents) =
  |||
    (
      (
         1 - %(ratioQuery)s
      ) * %(rangeInSeconds)s
    )
  ||| % {
    ratioQuery: errorBudgetRatio(range, selectors, aggregationLabels, ignoreComponents),
    rangeInSeconds: utils.rangeInSeconds(range),
  };

local budgetSecondsForRange(slaTarget, range) =
  |||
    # The number of seconds allowed to be spent in %(range)s
    %(budgetSeconds)s
  ||| % {
    range: range,
    budgetSeconds: utils.budgetSeconds(slaTarget, range),
  };

local errorBudgetTimeRemaining(slaTarget, range, selectors, aggregationLabels, ignoreComponents) =
  |||
    # The number of seconds allowed to be spent in %(range)s
    %(budgetSeconds)s
    -
    %(timeSpentQuery)s
  ||| % {
    range: range,
    budgetSeconds: utils.budgetSeconds(slaTarget, range),
    timeSpentQuery: errorBudgetTimeSpent(range, selectors, aggregationLabels, ignoreComponents),
  };

local errorBudgetRateAggregationInterpolation(range, groupSelectors, aggregationLabels, ignoreComponents) =
  local filteredAggregationLabels = std.filter(
    function(label) label != 'violation_type',
    aggregationLabels
  );
  {
    aggregationLabels: aggregations.join(filteredAggregationLabels),
    selectors: selectors.serializeHash(groupSelectors),
    range: range,
    ignoreCondition: ignoreCondition(ignoreComponents),
    aggregationsIncludingComponent: aggregations.join(filteredAggregationLabels + ignoredComponentJoinLabels),
  };

local errorBudgetViolationRate(range, groupSelectors, aggregationLabels, ignoreComponents) =
  local partsInterpolation = errorBudgetRateAggregationInterpolation(range, groupSelectors, aggregationLabels, ignoreComponents);
  local apdexViolationRate = |||
    sum by (%(aggregationLabels)s)(
      sum by (%(aggregationsIncludingComponent)s)(
        sum_over_time(
          gitlab:component:stage_group:execution:apdex:weight:score_1h{%(selectors)s}[%(range)s]
        ) -
        # Request with satisfactory apdex
        sum_over_time(
          gitlab:component:stage_group:execution:apdex:success:rate_1h{%(selectors)s}[%(range)s]
        )
      ) %(ignoreCondition)s
    )
  ||| % partsInterpolation;
  local errorRate = |||
    sum by (%(aggregationLabels)s)(
      sum by (%(aggregationsIncludingComponent)s)(
        sum_over_time(
          gitlab:component:stage_group:execution:error:rate_1h{%(selectors)s}[%(range)s]
        )
      ) %(ignoreCondition)s
    )
  ||| % partsInterpolation;
  |||
    sum by (%(aggregationLabelsWithViolationType)s) (
      %(apdexViolationRate)s
      or
      %(errorRate)s
    ) > 0
  ||| % {
    aggregationLabelsWithViolationType: aggregations.join(aggregationLabels),
    apdexViolationRate: strings.indent(strings.chomp(labels.addStaticLabel('violation_type', 'apdex', apdexViolationRate)), 2),
    errorRate: strings.indent(strings.chomp(labels.addStaticLabel('violation_type', 'error', errorRate)), 2),
  };

local errorBudgetOperationRate(range, groupSelectors, aggregationLabels, ignoreComponents) =
  local partsInterpolation = errorBudgetRateAggregationInterpolation(range, groupSelectors, aggregationLabels, ignoreComponents);
  local apdexOperationRate = |||
    sum by (%(aggregationLabels)s)(
      sum by (%(aggregationsIncludingComponent)s)(
        sum_over_time(
          gitlab:component:stage_group:execution:apdex:weight:score_1h{%(selectors)s}[%(range)s]
        )
      ) %(ignoreCondition)s
    )
  ||| % partsInterpolation;
  local errorOperationRate = |||
    sum by (%(aggregationLabels)s)(
      sum by (%(aggregationsIncludingComponent)s)(
        sum_over_time(
          gitlab:component:stage_group:execution:ops:rate_1h{%(selectors)s}[%(range)s]
        )
        and sum_over_time(gitlab:component:stage_group:execution:error:rate_1h{%(selectors)s}[%(range)s])
      ) %(ignoreCondition)s
    )
  ||| % partsInterpolation;
  |||
    sum by (%(aggregationLabelsWithViolationType)s) (
      %(apdexOperationRate)s
      or
      %(errorOperationRate)s
    ) > 0
  ||| % {
    aggregationLabelsWithViolationType: aggregations.join(aggregationLabels),
    apdexOperationRate: strings.indent(strings.chomp(labels.addStaticLabel('violation_type', 'apdex', apdexOperationRate)), 2),
    errorOperationRate: strings.indent(strings.chomp(labels.addStaticLabel('violation_type', 'error', errorOperationRate)), 2),
  };


{
  init(slaTarget, range): {
    errorBudgetRatio(selectors, aggregationLabels=[], ignoreComponents=true):
      errorBudgetRatio(range, selectors, aggregationLabels, ignoreComponents),
    errorBudgetTimeSpent(selectors, aggregationLabels=[], ignoreComponents=true):
      errorBudgetTimeSpent(range, selectors, aggregationLabels, ignoreComponents),
    budgetSecondsForRange():
      budgetSecondsForRange(slaTarget, range),
    errorBudgetTimeRemaining(selectors, aggregationLabels=[], ignoreComponents=true):
      errorBudgetTimeRemaining(slaTarget, range, selectors, aggregationLabels, ignoreComponents),
    errorBudgetViolationRate(selectors, aggregationLabels=[], ignoreComponents=true):
      errorBudgetViolationRate(range, selectors, aggregationLabels, ignoreComponents),
    errorBudgetOperationRate(selectors, aggregationLabels=[], ignoreComponents=true):
      errorBudgetOperationRate(range, selectors, aggregationLabels, ignoreComponents),
  },
}
