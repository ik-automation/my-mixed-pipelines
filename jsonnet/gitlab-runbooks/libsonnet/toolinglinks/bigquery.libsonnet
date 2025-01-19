local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'bigquery' });

{
  // SavedQuery can be obtained from the BigQuery interface.
  // Click "Link Sharing" and copy the URL
  // the savedQuery can be obtained from https://console.cloud.google.com/bigquery?sq=<savedQuery>
  bigquery(title, savedQuery)::
    function(options)
      [
        toolingLinkDefinition({
          title: 'BigQuery: ' + title,
          url: 'https://console.cloud.google.com/bigquery?project=gitlab-production&sq=%(savedQuery)s' % {
            savedQuery: savedQuery,
          },
        }),
      ],
}
