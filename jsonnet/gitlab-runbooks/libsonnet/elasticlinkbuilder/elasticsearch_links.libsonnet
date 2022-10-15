local indexCatalog = import 'elasticlinkbuilder/index_catalog.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local rison = import 'rison.libsonnet';

local rangeFilter = matching.rangeFilter;
local matchFilter = matching.matchFilter;
local existsFilter = matching.existsFilter;
local mustNot = matching.mustNot;
local matchAnyScriptFilter = matching.matchAnyScriptFilter;
local matcher = matching.matcher;

local grafanaTimeFrom = '${__from:date:iso}';
local grafanaTimeTo = '${__to:date:iso}';

local elasticTimeRange(from, to) =
  "(time:(from:'%(from)s',to:'%(to)s'))" % { from: from, to: to };

local grafanaTimeRange = elasticTimeRange(grafanaTimeFrom, grafanaTimeTo);

local globalState(str) =
  if str == null || str == '' then
    ''
  else
    '&_g=' + str;

// These are default prometheus label mappings, for mapping
// between prometheus labels and their equivalent ELK fields
// We know that these fields exist on most of our structured logs
// so we can safely map from the given labels to the fields in all cases
local defaultPrometheusLabelMappings = {
  type: 'json.type',
  stage: 'json.stage',
};

// This is similar to std.setUnion, except that the array order is maintained
// items from newItems will be added to array if they don't already exist
local appendUnion(array, newItems) =
  std.foldl(
    function(memo, item)
      if std.member(memo, item) then
        memo
      else
        memo + [item],
    newItems,
    array
  );

local buildElasticDiscoverSearchQueryURL(index, filters=[], luceneQueries=[], timeRange=grafanaTimeRange, sort=[], extraColumns=[]) =
  local ic = indexCatalog[index];

  local columnsWithExtras = appendUnion(indexCatalog[index].defaultColumns, extraColumns);

  local applicationState = {
    columns: columnsWithExtras,
    filters: ic.defaultFilters + filters,
    index: ic.indexPattern,
    [if std.length(luceneQueries) > 0 then 'query']: {
      language: 'kuery',
      query: std.join(' AND ', luceneQueries),
    },
    [if std.length(sort) > 0 then 'sort']: sort,
  };
  ic.kibanaEndpoint + '#/discover?_a=' + rison.encode(applicationState) + globalState(timeRange);

local buildElasticLineCountVizURL(index, filters, luceneQueries=[], splitSeries=false, timeRange=grafanaTimeRange) =
  local ic = indexCatalog[index];

  local aggs =
    [
      {
        enabled: true,
        id: '1',
        params: {},
        schema: 'metric',
        type: 'count',
      },
      {
        enabled: true,
        id: '2',
        params: {
          drop_partials: true,
          extended_bounds: {},
          field: ic.timestamp,
          interval: 'auto',
          min_doc_count: 1,
          scaleMetricValues: false,
          timeRange: {
            from: grafanaTimeFrom,
            to: grafanaTimeTo,
          },
          useNormalizedEsInterval: true,
        },
        schema: 'segment',
        type: 'date_histogram',
      },
    ]
    +
    (
      if splitSeries then
        [{
          enabled: true,
          id: '3',
          params: {
            field: ic.defaultSeriesSplitField,
            missingBucket: false,
            missingBucketLabel: 'Missing',
            order: 'desc',
            orderBy: '1',
            otherBucket: true,
            otherBucketLabel: 'Other',
            size: 5,
          },
          schema: 'group',
          type: 'terms',
        }]
      else
        []
    );

  local applicationState = {
    filters: ic.defaultFilters + filters,
    query: {
      language: 'kuery',
      query: std.join(' AND ', luceneQueries),
    },
    vis: {
      aggs: aggs,
    },
  };

  indexCatalog[index].kibanaEndpoint + '#/visualize/create?type=line&indexPattern=' + indexCatalog[index].indexPattern + '&_a=' + rison.encode(applicationState) + globalState(timeRange);

local splitDefinition(split, orderById='1') =
  local defaults = {
    enabled: true,
    schema: 'bucket',
  };

  if std.isString(split) then
    // When the split is a string, turn it into a 'term' split
    defaults {
      type: 'terms',
      params: {
        field: split,
        missingBucket: false,
        missingBucketLabel: 'Missing',
        otherBucket: true,
        otherBucketLabel: 'Other',
        orderBy: orderById,
        order: 'desc',
        size: 5,
      },
    }
  else if std.isObject(split) then defaults + split;

local buildElasticTableCountVizURL(index, filters, luceneQueries=[], splitSeries=false, timeRange=grafanaTimeRange, extraAggs=[], orderById='1') =
  local ic = indexCatalog[index];
  local aggs =
    [
      {
        enabled: true,
        id: '1',
        params: {},
        schema: 'metric',
        type: 'count',
      },
    ]
    +
    (
      if std.isBoolean(splitSeries) && splitSeries then
        [{
          enabled: true,
          id: '',
          params: {
            field: ic.defaultSeriesSplitField,
            missingBucket: false,
            missingBucketLabel: 'Missing',
            order: 'desc',
            orderBy: orderById,
            otherBucket: true,
            otherBucketLabel: 'Other',
            size: 5,
          },
          schema: 'group',
          type: 'terms',
        }]
      else if std.isArray(splitSeries) then
        [splitDefinition(split, orderById) for split in splitSeries]
      else
        []
    )
    +
    extraAggs;

  local applicationState = {
    filters: ic.defaultFilters + filters,
    query: {
      language: 'kuery',
      query: std.join(' AND ', luceneQueries),
    },
    vis: {
      aggs: aggs,
    },
  };

  indexCatalog[index].kibanaEndpoint + '#/visualize/create?type=table&indexPattern=' + indexCatalog[index].indexPattern + '&_a=' + rison.encode(applicationState) + globalState(timeRange);


local buildElasticLineTotalDurationVizURL(index, filters, luceneQueries=[], latencyField, splitSeries=false) =
  local ic = indexCatalog[index];

  local aggs =
    [
      {
        enabled: true,
        id: '1',
        params: {
          field: latencyField,
        },
        schema: 'metric',
        type: 'sum',
      },
      {
        enabled: true,
        id: '2',
        params: {
          drop_partials: true,
          extended_bounds: {},
          field: ic.timestamp,
          interval: 'auto',
          min_doc_count: 1,
          scaleMetricValues: false,
          timeRange: {
            from: grafanaTimeFrom,
            to: grafanaTimeTo,
          },
          useNormalizedEsInterval: true,
        },
        schema: 'segment',
        type: 'date_histogram',
      },
    ]
    +
    (
      if splitSeries then
        [{
          enabled: true,
          id: '3',
          params: {
            field: ic.defaultSeriesSplitField,
            missingBucket: false,
            missingBucketLabel: 'Missing',
            order: 'desc',
            orderBy: '1',
            otherBucket: true,
            otherBucketLabel: 'Other',
            size: 5,
          },
          schema: 'group',
          type: 'terms',
        }]
      else
        []
    );

  local applicationState = {
    filters: ic.defaultFilters + filters,
    query: {
      language: 'kuery',
      query: std.join(' AND ', luceneQueries),
    },
    vis: {
      aggs: aggs,
      params: {
        valueAxes: [
          {
            id: 'ValueAxis-1',
            name: 'LeftAxis-1',
            position: 'left',
            scale: {
              mode: 'normal',
              type: 'linear',
            },
            show: true,
            style: {},
            title: {
              text: 'Sum Request Duration: ' + latencyField,
            },
            type: 'value',
          },
        ],
      },
    },
  };

  indexCatalog[index].kibanaEndpoint + '#/visualize/create?type=line&indexPattern=' + indexCatalog[index].indexPattern + '&_a=' + rison.encode(applicationState) + globalState(grafanaTimeRange);

local buildElasticLinePercentileVizURL(index, filters, luceneQueries=[], latencyField, splitSeries=false) =
  local ic = indexCatalog[index];

  local aggs =
    [
      {
        enabled: true,
        id: '1',
        params: {
          field: latencyField,
          percents: [
            95,
          ],
        },
        schema: 'metric',
        type: 'percentiles',
      },
      {
        enabled: true,
        id: '2',
        params: {
          drop_partials: true,
          extended_bounds: {},
          field: ic.timestamp,
          interval: 'auto',
          min_doc_count: 1,
          scaleMetricValues: false,
          timeRange: {
            from: grafanaTimeFrom,
            to: grafanaTimeTo,
          },
          useNormalizedEsInterval: true,
        },
        schema: 'segment',
        type: 'date_histogram',
      },
    ] +
    (
      if splitSeries then
        [
          {
            enabled: true,
            id: '3',
            params: {
              field: ic.defaultSeriesSplitField,
              missingBucket: false,
              missingBucketLabel: 'Missing',
              order: 'desc',
              orderAgg: {
                enabled: true,
                id: '3-orderAgg',
                params: {
                  field: latencyField,
                },
                schema: 'orderAgg',
                type: 'sum',
              },
              orderBy: 'custom',
              otherBucket: true,
              otherBucketLabel: 'Other',
              size: 5,
            },
            schema: 'group',
            type: 'terms',
          },
        ]
      else
        []
    );

  local applicationState = {
    filters: ic.defaultFilters + filters,
    query: {
      language: 'kuery',
      query: std.join(' AND ', luceneQueries),
    },
    vis: {
      aggs: aggs,
      params: {
        valueAxes: [
          {
            id: 'ValueAxis-1',
            name: 'LeftAxis-1',
            position: 'left',
            scale: {
              mode: 'normal',
              type: 'linear',
            },
            show: true,
            style: {},
            title: {
              text: 'p95 Request Duration: ' + latencyField,
            },
            type: 'value',
          },
        ],
      },
    },
  };

  indexCatalog[index].kibanaEndpoint + '#/visualize/create?type=line&indexPattern=' + indexCatalog[index].indexPattern + '&_a=' + rison.encode(applicationState) + globalState(grafanaTimeRange);


{
  timeRange:: elasticTimeRange,

  // Given an index, and a set of filters, returns a URL to a Kibana discover module/search
  buildElasticDiscoverSearchQueryURL:: buildElasticDiscoverSearchQueryURL,

  // Search for failed requests
  buildElasticDiscoverFailureSearchQueryURL(index, filters=[], luceneQueries=[], timeRange=grafanaTimeRange, sort=[], extraColumns=[])::
    buildElasticDiscoverSearchQueryURL(
      index=index,
      filters=filters + indexCatalog[index].failureFilter,
      luceneQueries=luceneQueries,
      timeRange=timeRange,
      sort=sort,
      extraColumns=extraColumns
    ),

  // Search for requests taking longer than the specified number of seconds
  buildElasticDiscoverSlowRequestSearchQueryURL(index, filters=[], luceneQueries=[], slowRequestSeconds=null, timeRange=grafanaTimeRange, extraColumns=[])::
    local ic = indexCatalog[index];
    local slowRequestFilter = if std.objectHas(ic, 'slowRequestFilter') then ic.slowRequestFilter else [];
    local exceedingDurationFilter = if slowRequestSeconds != null then
      [rangeFilter(ic.defaultLatencyField, gteValue=slowRequestSeconds * ic.latencyFieldUnitMultiplier, lteValue=null)]
    else
      [];

    buildElasticDiscoverSearchQueryURL(
      index=index,
      filters=filters + slowRequestFilter + exceedingDurationFilter,
      timeRange=timeRange,
      sort=[[ic.defaultLatencyField, 'desc']],
      extraColumns=extraColumns
    ),

  // Given an index, and a set of filters, returns a URL to a Kibana count visualization
  buildElasticLineCountVizURL(index, filters, luceneQueries=[], splitSeries=false, timeRange=grafanaTimeRange,)::
    buildElasticLineCountVizURL(index, filters, luceneQueries, splitSeries=splitSeries, timeRange=timeRange),

  buildElasticLineFailureCountVizURL(index, filters, luceneQueries=[], splitSeries=false, timeRange=grafanaTimeRange)::
    buildElasticLineCountVizURL(
      index,
      filters + indexCatalog[index].failureFilter,
      luceneQueries,
      splitSeries=splitSeries,
      timeRange=timeRange,
    ),

  buildElasticTableCountVizURL:: buildElasticTableCountVizURL,
  buildElasticTableFailureCountVizURL(index, filters, luceneQueries=[], splitSeries=false, timeRange=grafanaTimeRange)::
    buildElasticTableCountVizURL(index, filters + indexCatalog[index].failureFilter, luceneQueries, splitSeries, timeRange),

  /**
   * Builds a total (sum) duration visualization. These queries are particularly useful for picking up
   * high volume short queries and can be useful in some types of incident investigations
   */
  buildElasticLineTotalDurationVizURL(index, filters, luceneQueries=[], field=null, splitSeries=false)::
    local fieldWithDefault = if field == null then
      indexCatalog[index].defaultLatencyField
    else
      field;
    buildElasticLineTotalDurationVizURL(index, filters, luceneQueries, fieldWithDefault, splitSeries=splitSeries),

  // Given an index, and a set of filters, returns a URL to a Kibana percentile visualization
  buildElasticLinePercentileVizURL(index, filters, luceneQueries=[], field=null, splitSeries=false)::
    local fieldWithDefault = if field == null then
      indexCatalog[index].defaultLatencyField
    else
      field;
    buildElasticLinePercentileVizURL(index, filters, luceneQueries, fieldWithDefault, splitSeries=splitSeries),

  // Returns true iff the named index supports request graphs (some do not have a concept of 'requests')
  indexSupportsRequestGraphs(index)::
    !std.objectHas(indexCatalog[index], 'requestsNotSupported'),

  // Returns true iff the named index supports failure queries
  indexSupportsFailureQueries(index)::
    std.objectHas(indexCatalog[index], 'failureFilter'),

  // Returns true iff the named index supports latency queries
  indexSupportsLatencyQueries(index)::
    std.objectHas(indexCatalog[index], 'defaultLatencyField'),

  indexHasSlowRequestFilter(index)::
    std.objectHas(indexCatalog[index], 'slowRequestFilter'),

  /**
   * Best-effort converter for a prometheus selector hash,
   * to convert it into a ES matcher.
   * Returns an array of zero or more matchers.
   */
  getMatchersForPrometheusSelectorHash(index, selectorHash)::
    local prometheusLabelMappings = defaultPrometheusLabelMappings + indexCatalog[index].prometheusLabelMappings;
    local labelValueTranslator = indexCatalog[index].prometheusLabelTranslators;

    std.flatMap(
      function(label)
        if std.objectHas(prometheusLabelMappings, label) then
          local selector = selectorHash[label];
          local selectorValue = if std.objectHas(labelValueTranslator, label) then
            labelValueTranslator[label](selector)
          else selector;

          // A mapping from this prometheus label to a ES field exists
          if std.isString(selectorValue) then
            [matchFilter(prometheusLabelMappings[label], selectorValue)]
          else if std.objectHas(selectorValue, 're') then
            // Most of the time, re contains a single value,
            // so treating it as such is better than ignoring
            [matchFilter(prometheusLabelMappings[label], selectorValue.re)]
          else if std.objectHas(selectorValue, 'eq') then
            // Most of the time, eq contains a single value,
            // so treating it as such is better than ignoring
            [matchFilter(prometheusLabelMappings[label], selectorValue.eq)]
          else if std.objectHas(selectorValue, 'ne') then
            // Most of the time, ne contains a single value,
            // so treating it as such is better than ignoring
            [mustNot(matchFilter(prometheusLabelMappings[label], selectorValue.ne))]
          else if std.objectHas(selectorValue, 'oneOf') then
            [matcher(prometheusLabelMappings[label], selectorValue.oneOf)]
          else if std.objectHas(selectorValue, 'noneOf') then
            [mustNot(matcher(prometheusLabelMappings[label], selectorValue.noneOf))]
          else
            assert false : 'Unsupported ES matcher %s' % [selectorValue];
            []
        else
          [],
      std.objectFields(selectorHash)
    ),

  getCustomTimeRange(from, to):: "(time:(from:'" + from + "',to:'" + to + "'))",

  dashboards:: {
    // A dashboard for reviewing rails log metrics
    // The caller_id is the route or the controller#action
    railsEndpointDashboard(caller_id, from='now-24', to='now')::
      local globalState = {
        filters: [
          {
            query: {
              match_phrase: {
                'json.meta.caller_id.keyword': '{{#url}}{{key}}{{/url}}',
              },
            },
          },
        ],
        time: { from: from, to: to },
      };
      local g = rison.encode(globalState);
      'https://log.gprd.gitlab.net/app/dashboards#/view/db37b560-9793-11eb-a990-d72c312ff8e9?_g=' + g,
  },
}
