local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'elastic_apm' });

{
  elasticAPM(service)::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Elastic APM: ' + service,
          url: 'https://log.gprd.gitlab.net/app/apm#/services/%(service)s/transactions' % {
            service: service,
          },
        }),
      ],
}
