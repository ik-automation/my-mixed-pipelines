local validator = import 'utils/validator.libsonnet';

local defaults = {
  type: 'instant',
};

// Supported query types should be defined here with their params
// See https://prometheus.io/docs/prometheus/latest/querying/api
// Adding a new type would also require adding the path in the `PrometheusApi` in
// lib/periodic_queries/prometheus_api.rb
local paramsPerType = {
  // https://prometheus.io/docs/prometheus/latest/querying/api/#instant-queries
  instant: ['query', 'time', 'timeout'],
};

local validateRequestParams(definition) =
  // The type field, should always be there, but it is not passed on when querying
  // all other fields will be passed on as request params when querying thanos.
  local supportedFields = paramsPerType[definition.type] + ['type'];
  local validationObject = {
    queryObject: definition,
  };

  local v = validator.new({
    queryObject: validator.validator(
      function(object)
        local definedFields = std.objectFields(object);
        std.setDiff(definedFields, supportedFields) == []
      , 'Only [%(fields)s] are supported for %(type)s queries' % {
        fields: std.join(', ', supportedFields),
        type: definition.type,
      }
    ),
  });
  v.assertValid(validationObject).queryObject;

local validateQuery(definition) =
  local v = validator.new({
    // Currently only instant queries are supported
    type: validator.setMember(std.objectFields(paramsPerType)),
    query: validator.string,
  });
  v.assertValid(definition);

local validate(definition) =
  validateQuery(definition) + validateRequestParams(definition);

local validateAndApplyDefaults(definition) =
  local definitionWithDefaults = defaults + definition;
  validate(definitionWithDefaults);

{
  new(definition):: validateAndApplyDefaults(definition),
}
