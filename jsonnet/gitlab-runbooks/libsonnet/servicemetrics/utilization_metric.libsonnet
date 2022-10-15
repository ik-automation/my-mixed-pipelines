local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local strings = import 'utils/strings.libsonnet';
local validator = import 'utils/validator.libsonnet';

local environmentLabels = ['environment', 'tier', 'type', 'stage'];

local definitionValidor = validator.new({
  rangeDuration: validator.string,
  title: validator.string,
  appliesTo: validator.array,
  description: validator.string,
  resourceLabels: validator.array,
  query: validator.string,
});

// Default values to apply to a utilization definition
local utilizationDefinitionDefaults = {
  rangeDuration: '1h',
  staticLabels: {},
  queryFormatConfig: {},
  /* When topk is set we record the topk items */
  topk: null,
};

local validateAndApplyDefaults(definition) =
  definitionValidor.assertValid(utilizationDefinitionDefaults + definition);

local utilizationMetric = function(options)
  local definition = validateAndApplyDefaults(options);
  local serviceApplicator = function(type) std.setMember(type, std.set(definition.appliesTo));

  definition {
    getTypeFilter()::
      (
        if std.length(definition.appliesTo) > 1 then
          { type: { re: std.join('|', definition.appliesTo) } }
        else
          { type: definition.appliesTo[0] }
      ),

    getFormatConfig()::
      local s = self;
      local selectorHash = s.getTypeFilter();
      local staticLabels = s.staticLabels;

      // Remove any statically defined labels from the selectors, if they are defined
      local selectorWithoutStaticLabels = selectors.without(selectorHash, staticLabels);

      local aggregationLabels = if s.topk == null then
        environmentLabels
      else
        environmentLabels + s.resourceLabels;

      local aggregationLabelsWithoutStaticLabels = std.filter(function(label) !std.objectHas(staticLabels, label), aggregationLabels);

      s.queryFormatConfig {
        rangeDuration: s.rangeDuration,
        selector: selectors.serializeHash(selectorWithoutStaticLabels),
        aggregationLabels: aggregations.serialize(aggregationLabelsWithoutStaticLabels),
        environmentLabels: aggregations.serialize(environmentLabels),
      },

    getTopkQuery()::
      local s = self;
      local formatConfig = s.getFormatConfig();
      local preaggregationQuery = s.query % formatConfig;

      |||
        topk by(%(environmentLabels)s) (%(topk)d,
          %(preaggregationQuery)s
        )
      ||| % formatConfig {
        topk: s.topk,
        preaggregationQuery: strings.indent(preaggregationQuery, 2),
      },

    getTotalQuery():: self.query % self.getFormatConfig(),

    getRecordingRuleQuery()::
      if self.topk == null then
        self.getTotalQuery()
      else
        self.getTopkQuery(),

    getLegendFormat()::
      if std.length(definition.resourceLabels) > 0 then
        std.join(' ', std.map(function(f) '{{ ' + f + ' }}', definition.resourceLabels))
      else
        '{{ type }}',

    getStaticLabels()::
      self.staticLabels,

    getRecordingRuleName(componentName)::
      local s = self;
      local formatConfig = {
        componentName: componentName,
        rangeDuration: s.rangeDuration,
        unit: s.unit,
        topKComponent: if s.topk == null then '' else 'topk:',
      };

      'gitlab_component_utilization:%(componentName)s_%(unit)s:%(topKComponent)s%(rangeDuration)s' % formatConfig,

    getRecordingRuleDefinitions(componentName)::
      local s = self;

      local labels = {
        component: componentName,
        unit: s.unit,
        metrics_subsystem: 'utilization',
        // In future, it might make more sense to move some of these labels onto a static "info" recording rule
        summaryType: if s.topk == null then 'aggregate' else 'topk',
        [if s.resourceLabels != [] then 'resource_labels']: std.join(',', s.resourceLabels),
      } + s.getStaticLabels();

      [{
        record: s.getRecordingRuleName(componentName),
        labels: labels,
        expr: s.getRecordingRuleQuery(),
      }],

    // Returns a boolean to indicate whether this saturation point applies to
    // a given service
    appliesToService(type)::
      serviceApplicator(type),

    // When a dashboard for this alert is opened without a type,
    // what should the default be?
    // For allowLists: always use the first item
    // For blockLists: use the default or web
    getDefaultGrafanaType()::
      definition.appliesTo[0],
  };

{
  utilizationMetric:: utilizationMetric,
}
