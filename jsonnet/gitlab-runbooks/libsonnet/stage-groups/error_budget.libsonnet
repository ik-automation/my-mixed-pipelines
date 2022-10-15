local standardSlaTarget = (import 'gitlab-metrics-config.libsonnet').slaTarget;
local initQueries = (import 'stage-groups/error-budget/queries.libsonnet').init;
local initPanels = (import 'stage-groups/error-budget/panels.libsonnet').init;
local utils = import 'stage-groups/error-budget/utils.libsonnet';

function(range='28d', slaTarget=standardSlaTarget)
  {
    /**
    * Configuration for the error budget
    * slaTarget: The target availability in a float, currently based on our overal slaTarget
    * range: 28d (1 month)
    */
    slaTarget: slaTarget,
    range: range,
    isDynamicRange: utils.isDynamicRange(range),
    /**
    * The queries and helper methods used for building PromQL queries for the error
    * budgets
    */
    queries: initQueries(self.slaTarget, range),

    /**
    * Panels for rendering on a grafana dashboard
    */
    panels: initPanels(self.queries, self.slaTarget, range),
  }
