local strings = import 'utils/strings.libsonnet';

// serializeItem supports 5 forms for the value:
// 1: for string values: -> `label="value"`
// 2: for equality values { eq: "value" } -> `label="value"`
// 3: for non-equality values { ne: "value" } -> `label!="value"`
// 4: for regex-match values { re: "value" } -> `label=~"value"`
// 5: for non-regex-match values { nre: "value" } -> `label!~"value"`

local serializeItemPair(label, operator, value) =
  local innerValue =
    if std.isString(value) then
      value
    else if std.isNumber(value) then
      '%g' % [value]
    else
      std.assertEqual(std.type(value), 'Illegal value');

  '%s%s"%s"' % [label, operator, innerValue];

local serializeItems(label, operator, value) =
  if std.isArray(value) then
    [serializeItemPair(label, operator, v) for v in value]
  else
    [serializeItemPair(label, operator, value)];

local serializeValue(expressionName, value) =
  if std.isString(value) then
    value
  else if std.isNumber(value) then
    '%g' % [value]
  else
    error '%s requires string or number values only' % [expressionName];

// TODO: at present, this doesn't support escaping regular expressions,
// so care should be taken to ensure that the values are safe
local serializeArrayItems(label, expressionName, operator, valueArray) =
  if std.isArray(valueArray) then
    if valueArray == [] then
      error '%s requires at least one value' % [expressionName]
    else
      local innerValue = std.map(function(value) serializeValue(expressionName, value), valueArray);
      local selectors = '%s%s"%s"' % [label, operator, std.join('|', std.set(innerValue))];
      [selectors]
  else
    error '%s must be an array. Got %s' % [expressionName, std.type(valueArray)];

local expressionFunctions = {
  re: function(label, value) serializeItems(label, '=~', value),
  nre: function(label, value) serializeItems(label, '!~', value),

  ne: function(label, value) serializeItems(label, '!=', value),
  eq: function(label, value) serializeItems(label, '=', value),

  oneOf: function(label, value) serializeArrayItems(label, 'oneOf', '=~', value),
  noneOf: function(label, value) serializeArrayItems(label, 'noneOf', '!~', value),
};

local serializeHashItem(label, value) =
  if std.isString(value) || std.isNumber(value) then
    serializeItems(label, '=', value)
  else if std.isArray(value) then
    // if the value is an array, iterate over the items
    std.flatMap(function(va) serializeHashItem(label, va), value)
  else
    std.flatMap(
      function(expression)
        local fn = std.get(expressionFunctions,
                           expression,
                           function(label, value) error '%s is not a valid expression' % [expression]);
        fn(label, value[expression]),
      std.objectFields(value)
    );

{
  // Joins an array of selectors and returns a serialized selector string
  join(selectors)::
    local selectorsSerialized = std.map(function(x) self.serializeHash(x), selectors);
    local nonEmptySelectors = std.filter(function(x) std.length(x) > 0, selectorsSerialized);
    std.join(', ', nonEmptySelectors),

  // Given selectors a,b creates a new selector that
  // is logically (a AND b)
  merge(a, b)::
    if a == null then
      b
    else if b == null then
      a
    else if std.isString(a) || std.isString(b) then
      self.join([self.serializeHash(a), self.serializeHash(b)])
    else
      a + b,

  // serializeHash converts a selector hash object into a prometheus selector query
  // The selector has is a hash with the form { "label_name": <value> }
  // Simple values represent the prometheus equality operator.
  // Object values can have 4 forms:
  // 1. Equality: { eq: "value" } -> `label="value"`
  // 2. Non-equality values { ne: "value" } -> `label!="value"`
  // 3. Regex-match values { re: "value" } -> `label=~"value"`
  // 4. Non-regex-match values { nre: "value" } -> `label!~"value"`
  // 5. In values { oneOf: ["value","v2"] } -> `label=~"value|v2"`
  // 6. Not-in values { noneOf: ["value","v2"] } -> `label!~"value|v2"`
  //
  // Examples:
  // - HASH --------------------------------------- SERIALIZED FORM ----------------
  // * { type: "gitlab" }                           type="gitlab"
  // * { type: { eq: "gitlab" } }                   type="gitlab"
  // * { type: { ne: "gitlab" } }                   type!="gitlab"
  // * { type: { re: "gitlab" } }                   type=~"gitlab"
  // * { type: { nre: "gitlab" } }                  type!~"gitlab"
  // * { type: "gitlab", job: { re: "redis.*"} }    type!~"gitlab",job=~"redis.*"
  // * { type: { oneOf: ["gitlab", "rocks"] } }     type=~"gitlab|rocks"
  // * { type: { noneOf: ["gitlab", "rocks"] } }    type!~"gitlab|rocks"
  // -------------------------------------------------------------------------------
  serializeHash(selectorHash, withBraces=false)::
    local optionalBraces(expr) =
      if expr == '' then ''
      else if withBraces then '{' + expr + '}'
      else expr;

    if selectorHash == null then
      ''
    else if std.isString(selectorHash) then
      optionalBraces(strings.chomp(selectorHash))
    else
      (
        local fields = std.set(std.objectFields(selectorHash));
        local pairs = std.flatMap(function(key) serializeHashItem(key, selectorHash[key]), fields);
        optionalBraces(std.join(',', pairs))
      ),

  // Expresses the selector syntax as an AlertManager matcher
  // https://prometheus.io/docs/alerting/latest/configuration/#matcher
  alertManagerMatchers(selectorHash)::
    local fields = std.set(std.objectFields(selectorHash));
    std.flatMap(function(key) serializeHashItem(key, selectorHash[key]), fields),

  // Remove certain selectors from a selectorHash
  without(selectorHash, labels)::
    if selectorHash == null then
      selectorHash
    else if std.length(labels) == 0 then
      selectorHash
    else if std.isString(selectorHash) then
      std.assertEqual(selectorHash, { __assert__: 'selectors.without requires a selector hash' })
    else
      local fields = std.set(std.objectFields(selectorHash));
      local labelSet = if std.isArray(labels) then std.set(labels) else std.set(std.objectFields(labels));
      local remaining = std.setDiff(fields, labelSet);

      std.foldl(function(memo, key)
                  memo { [key]: selectorHash[key] },
                remaining,
                {}),

  // Given a selector, returns the labels
  getLabels(selector)::
    if selector == '' then
      []
    else if selector == null then
      []
    else
      std.objectFields(selector),
}
