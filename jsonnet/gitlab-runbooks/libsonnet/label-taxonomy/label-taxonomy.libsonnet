// Consult the README.md file in this directory for more information
// on using label-taxomonies.
local labelTaxonomyConfig = (import 'gitlab-metrics-config.libsonnet').labelTaxonomy;
local aggregations = (import 'promql/aggregations.libsonnet');
local labels = (import './labels.libsonnet');

local labelTaxonomy(labelset) =
  local labelsFor(key) =
    local needed = (labelset & key) != 0;
    if needed then
      local value = labelTaxonomyConfig['' + key];
      if value != null then
        [value]
      else
        []
    else
      [];

  // Ensure order, from "biggest" to "smallest"
  labelsFor(labels.environmentThanos) +
  labelsFor(labels.environment) +
  labelsFor(labels.tier) +
  labelsFor(labels.service) +
  labelsFor(labels.stage) +
  labelsFor(labels.shard) +
  labelsFor(labels.node) +
  labelsFor(labels.sliComponent);

// Returns a comma deliminated string of labels according to the provided hash
local labelTaxonomySerialized(labelset) =
  local labels = labelTaxonomy(labelset);
  aggregations.serialize(labels);

// Returns the name of a specific label, or a default if it doesn't exist.
local getLabelFor(label, default='') =
  if std.isNumber(label) then
    local value = std.get(labelTaxonomyConfig, '' + label, default);
    if value == null then
      default
    else
      value
  else
    error 'getLabelFor() expects a value from labelTaxonomy.labels as the first argument';

// Returns true if a specific taxonomy label exists in the configuration
local hasLabelFor(label) =
  if std.isNumber(label) then
    std.get(labelTaxonomyConfig, '' + label, null) != null
  else
    error 'hasLabelFor() expects a value from labelTaxonomy.labels as the first argument';


{
  labels:: labels,
  getLabelFor:: getLabelFor,
  hasLabelFor:: hasLabelFor,
  labelTaxonomy:: labelTaxonomy,
  labelTaxonomySerialized:: labelTaxonomySerialized,
}
