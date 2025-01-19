local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'kibana', type:: 'log' });
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';

{
  kibana(
    title,
    index,
    type=null,
    tag=null,
    shard=null,
    message=null,
    slowRequestSeconds=null,
    matches={},
    includeMatchersForPrometheusSelector=true
  )::
    function(options)
      local supportsRequests = elasticsearchLinks.indexSupportsRequestGraphs(index);
      local supportsFailures = elasticsearchLinks.indexSupportsFailureQueries(index);
      local supportsLatencies = elasticsearchLinks.indexSupportsLatencyQueries(index);
      local includeSlowRequests = supportsLatencies &&
                                  (slowRequestSeconds != null || elasticsearchLinks.indexHasSlowRequestFilter(index));
      local filters =
        (
          if type == null then
            []
          else
            [matching.matchFilter('json.type.keyword', type)]
        )
        +
        (
          if tag == null then
            []
          else
            [matching.matchFilter('json.tag.keyword', tag)]
        )
        +
        (
          if shard == null then
            []
          else
            [matching.matchFilter('json.shard.keyword', shard)]
        )
        +
        (
          if message == null then
            []
          else
            [matching.matchFilter('json.message.keyword', message)]
        )
        +
        matching.matchers(matches)
        +
        (
          if includeMatchersForPrometheusSelector then
            elasticsearchLinks.getMatchersForPrometheusSelectorHash(index, options.prometheusSelectorHash)
          else
            []
        );

      [
        toolingLinkDefinition({
          title: '📖 Kibana: ' + title + ' logs',
          url: elasticsearchLinks.buildElasticDiscoverSearchQueryURL(index, filters),
        }),
      ]
      +
      (
        if includeSlowRequests then
          [
            toolingLinkDefinition({
              title: '📖 Kibana: ' + title + ' slow request logs',
              url: elasticsearchLinks.buildElasticDiscoverSlowRequestSearchQueryURL(index, filters, slowRequestSeconds=slowRequestSeconds),
            }),
          ]
        else []
      )
      +
      (
        if supportsFailures then
          [
            toolingLinkDefinition({
              title: '📖 Kibana: ' + title + ' failed request logs',
              url: elasticsearchLinks.buildElasticDiscoverFailureSearchQueryURL(index, filters),
            }),
          ]
        else
          []
      )
      +
      (
        if supportsRequests then
          [
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' requests',
              url: elasticsearchLinks.buildElasticLineCountVizURL(index, filters),
              type:: 'chart',
            }),
          ]
        else
          []
      )
      +
      (
        if supportsFailures then
          [
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' failed requests',
              url: elasticsearchLinks.buildElasticLineFailureCountVizURL(index, filters),
              type:: 'chart',
            }),
          ]
        else
          []
      )
      +
      (
        if supportsLatencies then
          [
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' sum latency aggregated',
              url: elasticsearchLinks.buildElasticLineTotalDurationVizURL(index, filters, splitSeries=true),
              type:: 'chart',
            }),
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' sum latency aggregated (split)',
              url: elasticsearchLinks.buildElasticLineTotalDurationVizURL(index, filters, splitSeries=true),
              type:: 'chart',
            }),
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' percentile latency aggregated',
              url: elasticsearchLinks.buildElasticLinePercentileVizURL(index, filters, splitSeries=false),
              type:: 'chart',
            }),
            toolingLinkDefinition({
              title: '📈 Kibana: ' + title + ' percentile latency aggregated (split)',
              url: elasticsearchLinks.buildElasticLinePercentileVizURL(index, filters, splitSeries=true),
              type:: 'chart',
            }),
          ]
        else
          []
      ),
}
