local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'stackdriver', type:: 'log' });
local url = import 'github.com/jsonnet-libs/xtd/url.libsonnet';

local safeQuotedString(string) =
  {
    safeQuotedString: string,
  };

local serializeQueryHashValue(value) =
  if std.isString(value) then
    '"%s"' % [value]
  else if std.isObject(value) && std.objectHas(value, 'safeQuotedString') then
    value.safeQuotedString
  else
    value;

local serializeQueryHashItemUnwrapped(key, op, value, prefix='') =
  '%(prefix)s%(key)s%(op)s%(value)s' % {
    key: key,
    op: op,
    value: serializeQueryHashValue(value),
    prefix: prefix,
  };

local serializeQueryHashItem(key, op, value, prefix='') =
  if std.isArray(value) then
    std.map(function(item) serializeQueryHashItemUnwrapped(key, op, item, prefix), value)
  else
    [serializeQueryHashItemUnwrapped(key, op, value, prefix)];

local serializeOneOf(key, values) =
  local serializedValues = std.map(serializeQueryHashValue, values);
  local joinedValues = std.join(' OR ', serializedValues);
  [
    '%(key)s=(%(joinedValues)s)' % {
      key: key,
      joinedValues: joinedValues,
    },
  ];

local serializeQueryHashPair(key, value) =
  if value == null then
    []
  else if !std.isObject(value) then
    serializeQueryHashItem(key, '=', value)
  else if std.objectHas(value, 'ne') then
    serializeQueryHashItem(key, '=', value.ne, prefix='-')
  else if std.objectHas(value, 'gt') then
    serializeQueryHashItem(key, '>', value.gt)
  else if std.objectHas(value, 'gte') then
    serializeQueryHashItem(key, '>=', value.gte)
  else if std.objectHas(value, 'lt') then
    serializeQueryHashItem(key, '<', value.lt)
  else if std.objectHas(value, 'lte') then
    serializeQueryHashItem(key, '<=', value.lte)
  else if std.objectHas(value, 'contains') then
    serializeQueryHashItem(key, ':', value.contains)
  else if std.objectHas(value, 'exists') then
    serializeQueryHashItem(key, ':', safeQuotedString('*'), prefix=if value.exists then '' else '-')
  else if std.objectHas(value, 'one_of') then
    serializeOneOf(key, value.one_of)
  else
    std.assertEqual(value, { __message__: 'unknown operator' });

// https://cloud.google.com/logging/docs/view/advanced-queries
local serializeQueryHash(hash) =
  local keys = std.objectFields(hash);
  local lines = std.flatMap(
    function(key)
      local value = hash[key];
      if std.isArray(value) then
        std.flatMap(
          function(item)
            serializeQueryHashPair(key, item),
          value
        )
      else
        serializeQueryHashPair(key, value),
    keys
  );
  std.join('\n', lines);

local stackdriverLogsEntry(
  title,
  queryHash,
  project='gitlab-production',
  timeRange='PT30M',
      ) =
  function(options)
    toolingLinkDefinition({
      title: title,
      url: 'https://console.cloud.google.com/logs/query;query=%(query)s;timeRange=%(timeRange)s?project=%(project)s' % {
        project: project,
        timeRange: timeRange,
        query: url.escapeString(serializeQueryHash(queryHash)),
      },
    });

{
  // Given a hash, returns a textual stackdriver logs query
  serializeQueryHash:: serializeQueryHash,

  stackdriverLogs(
    title,
    queryHash,
    project='gitlab-production',
    timeRange='PT30M',
  )::
    local entry = stackdriverLogsEntry(
      title=title,
      queryHash=queryHash,
      project=project,
      timeRange=timeRange,
    );

    function(options)
      [
        entry(options),
      ],

  // Returns a link to a stackdriver logging query
  stackdriverLogsEntry:: stackdriverLogsEntry,
}
