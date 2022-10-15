local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local baseSelector = {
  stage: '$stage',
  environment: '$environment',
  monitor: 'global',
};

local groupSelector = {
  product_stage: { re: '$product_stage' },
  stage_group: { re: '$stage_group' },
};

local mappingSelector = {
  monitor: 'global',
};

local knownEndpointsSelector = { endpoint_id: { ne: 'unknown' } };
local componentSelector = { component: 'rails_requests' };
local stageGroupAggregationLabels = ['product_stage', 'stage_group'];
local knownUrgencies = ['high', 'medium', 'default', 'low'];

local percentageOfTrafficByUrgency(urgencySelector) =
  |||
    (
      sum by (request_urgency) (
        sum by (request_urgency, feature_category)(
          sum_over_time(application_sli_aggregation:rails_request_apdex:apdex:weight:score_1h{%(numeratorSelector)s}[6h]) > 0
        ) * on (feature_category) group by (stage_group,product_stage,feature_category) (gitlab:feature_category:stage_group:mapping{%(stageGroupSelector)s})
      )
      / ignoring(request_urgency) group_left() sum(
        sum by (feature_category)(
          sum_over_time(application_sli_aggregation:rails_request_apdex:apdex:weight:score_1h{%(denominatorSelector)s}[6h]) > 0
        ) * on (feature_category) group by (stage_group,product_stage,feature_category) (gitlab:feature_category:stage_group:mapping{%(stageGroupSelector)s})
      )
    )
  ||| % {
    numeratorSelector: selectors.serializeHash(baseSelector + knownEndpointsSelector + urgencySelector),
    denominatorSelector: selectors.serializeHash(baseSelector + knownEndpointsSelector),
    stageGroupSelector: selectors.serializeHash(groupSelector + mappingSelector),
  };

local numberOfEndpointsPromQL(selector) = |||
  count(
    count by (endpoint_id, feature_category) (
      count_over_time(application_sli_aggregation:rails_request_apdex:apdex:weight:score_1h{%(selector)s}[6h]) > 0
    ) * on (feature_category) group_left() group by (stage_group,product_stage,feature_category) (gitlab:feature_category:stage_group:mapping{%(stageGroupSelector)s})
  )
||| % {
  selector: selectors.serializeHash(baseSelector + knownEndpointsSelector + selector),
  stageGroupSelector: selectors.serializeHash(groupSelector + mappingSelector),
};

local topEndpoints(selector) = |||
  sort_desc(
    sum by (feature_category, endpoint_id)(
      sum_over_time(application_sli_aggregation:rails_request_apdex:apdex:weight:score_1h{%(selector)s}[6h])
    ) * on (feature_category) group_left(stage_group, product_stage) group by (stage_group,product_stage,feature_category) (gitlab:feature_category:stage_group:mapping{%(stageGroupSelector)s})
  )
||| % {
  selector: selectors.serializeHash(baseSelector + knownEndpointsSelector + selector),
  stageGroupSelector: selectors.serializeHash(groupSelector + mappingSelector),
};

local trafficForUrgency(urgency) =
  basic.statPanel(
    '',
    '%s urgency requests' % [urgency],
    'blue',
    percentageOfTrafficByUrgency({ request_urgency: urgency }),
    '{{ urgency }}',
    unit='percentunit',
  );

local endpointCountForUrgency(urgency) =
  basic.statPanel(
    '%s urgency endpoints' % [urgency],
    '',
    'blue',
    numberOfEndpointsPromQL({ request_urgency: urgency }),
    '',
  );

local endpointsForUrgency(urgency) =
  basic.table(
    title='%s urgency endpoints ordered by request rate' % [urgency],
    styles=null,
    queries=[topEndpoints({ request_urgency: urgency })],
    transformations=[
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            feature_category: true,
            product_stage: true,
          },
          indexByName: {
            stage_group: 1,
            endpoint_id: 2,
            Value: 3,
          },
          renameByName: {
            stage_group: 'Group',
            Value: 'Rate',
          },
        },
      },
    ],
  ) {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Stage',
          },
          properties: [{
            id: 'custom.width',
            value: 80,
          }],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Group',
          },
          properties: [{
            id: 'custom.width',
            value: 130,
          }],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Rate',
          },
          properties: [{
            id: 'custom.width',
            value: 80,
          }],
        },
      ],
    },
  };

local trafficForUrgencyPanels(urgency) =
  [
    trafficForUrgency(urgency),
    endpointCountForUrgency(urgency),
  ];

local groupOptedOut = |||
  (
    sum by(%(aggregationLabels)s)(gitlab:ignored_component:stage_group{%(selector)s})
    or
    sum by (%(aggregationLabels)s)(0 * gitlab:feature_category:stage_group:mapping{%(stageGroupSelector)s})
  ) and sum by (%(aggregationLabels)s) (sum_over_time(gitlab:component:stage_group:execution:ops:rate_6h{%(selector)s}[$__range])) > 0
||| % {
  stageGroupSelector: selectors.serializeHash(groupSelector),
  selector: selectors.serializeHash(componentSelector + groupSelector),
  aggregationLabels: aggregations.serialize(stageGroupAggregationLabels),
};

local percentageOfTrafficForComponent(aggregationLabels) = |||
  sum by (%(aggregationLabels)s)(
    sum_over_time(gitlab:component:stage_group:execution:ops:rate_6h{%(selector)s}[$__range]) > 0
  )
  / ignoring(%(totalAggregationLabels)s) group_left() sum(
      sum_over_time(gitlab:component:stage_group:execution:ops:rate_6h{%(selector)s}[$__range]) > 0
  )
||| % {
  selector: selectors.serializeHash(baseSelector + groupSelector + componentSelector),
  aggregationLabels: aggregations.serialize(aggregationLabels),
  totalAggregationLabels: aggregations.serialize(aggregationLabels),
};

local apdexRatioPromql(selector) = |||
  clamp_max(
    sum by (%(aggregationLabels)s)(
      sum_over_time(gitlab:component:stage_group:execution:apdex:success:rate_6h{%(selector)s}[$__range]) > 0
    )
    /
    sum by (%(aggregationLabels)s)(
      sum_over_time(gitlab:component:stage_group:execution:apdex:weight:score_6h{%(selector)s}[$__range]) > 0
    ),
    1
  )
||| % {
  selector: selectors.serializeHash(baseSelector + groupSelector + selector),
  aggregationLabels: aggregations.serialize(stageGroupAggregationLabels),
};

local optOutTraffic =
  local aggregationLabels = stageGroupAggregationLabels + ['component'];
  |||
    sum (
      sum by (%(aggregationLabels)s) (gitlab:ignored_component:stage_group{%(selector)s})
      * (
        %(percentageOfTrafficByGroup)s
      )
    )
  ||| % {
    aggregationLabels: aggregations.serialize(aggregationLabels),
    selector: selectors.serializeHash(groupSelector + componentSelector),
    percentageOfTrafficByGroup: percentageOfTrafficForComponent(aggregationLabels),
  };

local optInTraffic =
  local aggregationLabels = stageGroupAggregationLabels + ['component'];
  |||
    sum(
      (
        %(percentageOfTrafficByGroup)s
      ) unless on (%(aggregationLabels)s) (gitlab:ignored_component:stage_group{%(selector)s})
    )
  ||| % {
    aggregationLabels: aggregations.serialize(aggregationLabels),
    selector: selectors.serializeHash(groupSelector + componentSelector),
    percentageOfTrafficByGroup: percentageOfTrafficForComponent(aggregationLabels),
  }
;

local optOutTrafficShare =
  basic.multiTimeseries(
    title='Traffic opted in',
    format='percentunit',
    fill=1,
    queries=[
      {
        query: optInTraffic,
        legendFormat: 'opted in',
      },
      {
        query: optOutTraffic,
        legendFormat: 'opted out',
      },
    ],
    stack=true,
  );

local optOutGroupsTable =
  basic.table(
    title='groups opted in to the rails_request component',
    styles=null,
    queries=[
      groupOptedOut,
      percentageOfTrafficForComponent(stageGroupAggregationLabels),
      apdexRatioPromql(componentSelector),
      apdexRatioPromql({ component: 'puma' }),
    ],
    transformations=[
      { id: 'merge' },
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
          },
          indexByName: {
            product_stage: 0,
            stage_group: 1,
            'Value #A': 2,
            'Value #B': 3,
            'Value #C': 4,
          },
          renameByName: {
            product_stage: 'Stage',
            stage_group: 'Group',
            'Value #A': 'Opted in',
            'Value #B': 'Percentage of traffic',
            'Value #C': 'New apdex ratio',
            'Value #D': 'Old apdex ratio',
          },
        },
      },
    ],
  ) {
    options: {
      sortBy: [{
        displayName: 'Percentage of traffic',
        desc: true,
      }],
    },
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Opted in',
          },
          properties: [
            {
              id: 'mappings',
              value: [
                {
                  type: 'value',
                  options: {
                    '0': {
                      text: '💚',
                      index: 1,
                    },
                    '1': {
                      text: '⏳',
                      index: 0,
                    },
                  },
                },
              ],
            },
          ],
        },
        {
          matcher: {
            id: 'byRegexp',
            options: '(Percentage of traffic)|(ratio)',
          },
          properties: [
            {
              id: 'unit',
              value: 'percentunit',
            },
            {
              id: 'decimals',
              value: 2,
            },
            {
              id: 'custom.width',
              value: 130,
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Stage',
          },
          properties: [{
            id: 'custom.width',
            value: 80,
          }],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Opted in',
          },
          properties: [{
            id: 'custom.width',
            value: 80,
          }],
        },
      ],
    },
  };

basic.dashboard(
  'Request apdex participation',
  tags=[],
  time_from='now-7d/m',
  time_to='now/m',
).addTemplate(prebuiltTemplates.environment)
.addTemplate(prebuiltTemplates.stage)
.addTemplate(prebuiltTemplates.productStage())
.addTemplate(prebuiltTemplates.stageGroup())
.addPanels(
  layout.splitColumnGrid(
    std.map(trafficForUrgencyPanels, knownUrgencies),
    title='Traffic by urgency (over the last 6h)',
    startRow=0,
    cellHeights=[4, 2],
  )
)
.addPanels(
  layout.rowGrid(
    'Endpoints by urgency (over the last 6h)',
    std.map(endpointsForUrgency, knownUrgencies),
    collapse=true,
    startRow=100,
  )
)
.addPanels(
  layout.rowGrid(
    'Opted in groups',
    [optOutGroupsTable],
    rowHeight=10,
    startRow=200,
  )
).addPanels(
  layout.rowGrid(
    'Opted in traffic over time',
    [optOutTrafficShare],
    rowHeight=10,
    startRow=300,
  )
)
