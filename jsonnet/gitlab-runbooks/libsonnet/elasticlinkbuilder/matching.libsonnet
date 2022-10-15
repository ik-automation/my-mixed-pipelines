// Builds an ElasticSearch match filter clause
local matchFilter(field, value) =
  {
    query: {
      match: {
        [field]: {
          query: value,
          type: 'phrase',
        },
      },
    },
    meta: {
      key: field,
      type: 'phrase',
      params: value,
    },
  };

local matchInFilter(field, possibleValues) =
  {
    query: {
      bool: {
        should: [{ match_phrase: { [field]: possibleValue } } for possibleValue in possibleValues],
        minimum_should_match: 1,
      },
    },
    meta: {
      key: field,
      type: 'phrases',
      params: possibleValues,
    },
  };

// Builds an ElasticSearch range filter clause
local rangeFilter(field, gteValue, lteValue) =
  local params = {
    [if gteValue != null then 'gte']: gteValue,
    [if lteValue != null then 'lte']: lteValue,
  };

  {
    query: {
      range: {
        [field]: params,
      },
    },
    meta: {
      key: field,
      type: 'range',
      params: params,
    },
  };

local existsFilter(field) =
  {
    query: {
      exists: {
        field: field,
      },
    },
    meta: {
      key: 'exists',
      type: field,
      value: 'exists',
    },
  };

local mustNot(filter) =
  filter {
    meta+: {
      negate: true,
    },
  };

local matchAnyScriptFilter(scripts) =
  local query = {
    bool: {
      should: [
        { script: { script: { source: script } } }
        for script in scripts
      ],
      minimum_should_match: 1,
    },
  };
  {
    query: query,
    meta: {
      key: 'query',
      type: 'custom',
      value: std.toString(query),
    },
  };

local matchObject(fieldName, matchInfo) =
  local gte = if std.objectHas(matchInfo, 'gte') then matchInfo.gte else null;
  local lte = if std.objectHas(matchInfo, 'lte') then matchInfo.lte else null;
  local values = std.prune([gte, lte]);

  if std.length(values) > 0 then
    rangeFilter(fieldName, gte, lte)
  else
    std.assertEqual(false, { __message__: 'Only gte and lte fields are supported but not in [%s]' % std.join(', ', std.objectFields(matchInfo)) });

local matcher(fieldName, matchInfo) =
  if fieldName == 'anyScript' && std.isArray(matchInfo) then
    matchAnyScriptFilter(matchInfo)
  else if std.isString(matchInfo) then
    matchFilter(fieldName, matchInfo)
  else if std.isArray(matchInfo) then
    matchInFilter(fieldName, matchInfo)
  else if std.isObject(matchInfo) then
    matchObject(fieldName, matchInfo);

local matchers(matches) =
  [
    matcher(k, matches[k])
    for k in std.objectFields(matches)
  ];


{
  matcher:: matcher,
  matchers:: matchers,
  matchFilter:: matchFilter,
  matchInFilter:: matchInFilter,
  existsFilter:: existsFilter,
  rangeFilter:: rangeFilter,
  mustNot:: mustNot,
}
