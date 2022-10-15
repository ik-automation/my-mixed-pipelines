local strings = import 'utils/strings.libsonnet';

local serialize(labels) =
  if std.isString(labels) then
    strings.chomp(labels)
  else
    std.join(',', labels);

{
  // Given an array of aggregation labels, formats as a string
  serialize(labels)::
    serialize(labels),

  // Joins an array of aggregation labels and returns a serialized string
  join(labels)::
    local labelsSerialized = std.map(function(x) self.serialize(x), labels);
    local uniqueLabels = std.set(labelsSerialized);
    local nonEmptyLabels = std.filter(function(x) std.length(x) > 0, uniqueLabels);
    std.join(',', nonEmptyLabels),

  // Wraps a query in an aggregation function, using the provided aggregation labels
  aggregateOverQuery(aggregationFunction, aggregationLabels, query)::
    |||
      %(aggregationFunction)s by (%(aggregationLabels)s) (
        %(query)s
      )
    ||| % {
      aggregationFunction: aggregationFunction,
      aggregationLabels: serialize(aggregationLabels),
      query: strings.indent(strings.chomp(query), 2),
    },
}
