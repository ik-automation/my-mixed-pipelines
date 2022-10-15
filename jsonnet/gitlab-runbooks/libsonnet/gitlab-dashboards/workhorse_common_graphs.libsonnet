local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

{
  workhorsePanels(serviceType, serviceStage, startRow)::
    local formatConfig = {
      serviceType: serviceType,
      serviceStage: serviceStage,
    };
    local elasticFilters = [
      matching.matchFilter('json.type.keyword', serviceType),
      matching.matchFilter('json.stage.keyword', serviceStage),
    ];

    local elasticWorkhorseDataLink = {
      url: elasticsearchLinks.buildElasticDiscoverSearchQueryURL('workhorse', elasticFilters),
      title: 'ElasticSearch: workhorse logs',
      targetBlank: true,
    };

    local elasticWorkhorseVisDataLink = {
      url: elasticsearchLinks.buildElasticLineCountVizURL('workhorse', elasticFilters),
      title: 'ElasticSearch: workhorse visualization',
      targetBlank: true,
    };

    layout.grid([
      basic.latencyTimeseries(
        title='p50 Overall Latency Estimate',
        description='p50 Latency. Lower is better',
        query=|||
          histogram_quantile(
            0.5,
            sum(
              job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                environment="$environment",
                type="%(serviceType)s",
                stage="%(serviceStage)s"}
            ) by (le))
        ||| % formatConfig,
        legendFormat='{{ method }} {{ route }}',
        format='s',
        min=0.001,
        yAxisLabel='Latency',
        interval='1m',
        intervalFactor=1,
        logBase=10
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.latencyTimeseries(
        title='p90 Latency Estimate per Route',
        description='90th percentile Latency. Lower is better',
        query=|||
          label_replace(
            histogram_quantile(
              0.9,
              sum(
                job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                  environment="$environment",
                  type="%(serviceType)s",
                  stage="%(serviceStage)s"}
              ) by (route, le)),
          "route", "none", "route", "")
        ||| % formatConfig,
        legendFormat='{{ method }} {{ route }}',
        format='s',
        min=0.001,
        yAxisLabel='Latency',
        interval='1m',
        intervalFactor=1,
        logBase=10
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.latencyTimeseries(
        title='p50 Latency Estimate per Route',
        description='Median Latency. Lower is better',
        query=|||
          label_replace(
            histogram_quantile(
              0.5,
              sum(
                job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                  environment="$environment",
                  type="%(serviceType)s",
                  stage="%(serviceStage)s"}
              ) by (route, le)),
          "route", "none", "route", "")
        ||| % formatConfig,
        legendFormat='{{ method }} {{ route }}',
        format='s',
        min=0.001,
        yAxisLabel='Latency',
        interval='1m',
        intervalFactor=1,
        logBase=10
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.timeseries(
        title='Total Requests',
        description='Total Requests',
        query=|||
          sum(
            job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                environment="$environment",
                type="%(serviceType)s",
                stage="%(serviceStage)s",
                le="+Inf"}
          )
        ||| % formatConfig,
        legendFormat='{{ code_class }}',
        interval='1m',
        intervalFactor=1,
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.timeseries(
        title='Requests by Status Class',
        description='Requests by Status Class',
        query=|||
          sum(
            label_replace(
              sum(
                job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                    environment="$environment",
                    type="%(serviceType)s",
                    stage="%(serviceStage)s",
                    le="+Inf"}
              ) by (code),
            "code_class", "${1}XX", "code", "(.).*")
          ) by (code_class)
        ||| % formatConfig,
        legendFormat='{{ code_class }}',
        interval='1m',
        intervalFactor=1,
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.timeseries(
        title='Requests by Status Code',
        description='Requests by Status Code',
        query=|||
          sum(
            job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                environment="$environment",
                type="%(serviceType)s",
                stage="%(serviceStage)s",
                le="+Inf"}
          ) by (code)
        ||| % formatConfig,
        legendFormat='{{ code }}',
        interval='1m',
        intervalFactor=1,
        legend_show=false,
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
      basic.timeseries(
        title='Requests by Route',
        description='Requests by Route',
        query=|||
          sum(
            label_replace(
              sum(
                job:gitlab_workhorse_http_request_duration_seconds_bucket:rate1m{
                    environment="$environment",
                    type="%(serviceType)s",
                    stage="%(serviceStage)s",
                    le="+Inf"}
              ) by (route),
            "route", "none", "route", "")
          ) by (route)
        ||| % formatConfig,
        legendFormat='{{ route }}',
        interval='1m',
        intervalFactor=1,
      )
      .addDataLink(elasticWorkhorseDataLink)
      .addDataLink(elasticWorkhorseVisDataLink),
    ], cols=2, rowHeight=10, startRow=startRow),

}
