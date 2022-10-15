local sliDefinition = import 'gitlab-slis/sli-definition.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';

local list = [
  sliDefinition.new({
    name: 'rails_request',
    significantLabels: ['endpoint_id', 'feature_category', 'request_urgency'],
    kinds: [sliDefinition.apdexKind],
    description: |||
      The number of requests meeting their duration target based on the urgency
      of the endpoint. By default, a request should take no more than 1s. But
      this can be adjusted by endpoint.

      Read more about this in the [documentation](https://docs.gitlab.com/ee/development/application_slis/rails_request_apdex.html).
    |||,
  }),
  sliDefinition.new({
    name: 'graphql_query',
    significantLabels: ['endpoint_id', 'feature_category', 'query_urgency'],
    kinds: [sliDefinition.apdexKind],
    description: |||
      The number of GraphQL queries meeting their duration target based on the urgency
      of the endpoint. By default, a query should take no more than 1s. We're working
      on making the urgency customizable in [this epic](https://gitlab.com/groups/gitlab-org/-/epics/5841).

      Mutliple queries could be batched inside a single request.
    |||,
  }),
  sliDefinition.new({
    name: 'customers_dot_sidekiq_jobs',
    significantLabels: ['endpoint_id', 'feature_category'],
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of CustomersDot jobs meeting their duration target for their execution.
      By default, a Sidekiq job should take no more than 5 seconds. But
      this can be adjusted by endpoint.
    |||,
  }),
  sliDefinition.new({
    name: 'customers_dot_requests',
    significantLabels: ['endpoint_id', 'feature_category'],
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of CustomersDot requests meeting their duration target based on the urgency
      of the endpoint. By default, a request should take no more than 0.4s. But
      this can be adjusted by endpoint.
    |||,
  }),
  sliDefinition.new({
    name: 'global_search',
    significantLabels: ['endpoint_id', 'search_level', 'search_scope', 'search_type'],
    kinds: [sliDefinition.apdexKind],
    featureCategory: 'global_search',
    description: |||
      The number of Global Search search requests meeting their duration target based on the 99.95th percentile of
      the search with the same parameters.
    |||,
  }),
  sliDefinition.new({
    name: 'global_search_indexing',
    significantLabels: ['document_type'],
    kinds: [sliDefinition.apdexKind],
    featureCategory: 'global_search',
    description: |||
      The number of Global Search indexing calls meeting their duration target based on the 99.95th percentile of
      indexing. This indicates the duration between when an item was changed and when it became available in Elasticsearch.

      The target duration can be found here:
      https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/metrics/global_search_indexing_slis.rb#L14-L15
    |||,
  }),
];

local definitionsByName = std.foldl(
  function(memo, definition)
    assert !std.objectHas(memo, definition.name) : '%s already defined' % [definition.name];
    memo { [definition.name]: definition },
  list,
  {}
);

{
  get(name):: definitionsByName[name],
  all:: list,
}
