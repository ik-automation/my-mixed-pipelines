local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

{
  // These tooling links are GitLab.com specific, so we don't put them into the archetype
  gitlabcomObservabilityToolingForPgbouncer(pgbouncerType)::
    {
      serviceLevelIndicators+: {
        service+: {
          toolingLinks+: [
            toolingLinks.kibana(title='pgbouncer', index='postgres_pgbouncer', type=pgbouncerType, tag='postgres.pgbouncer'),
          ],
        },
      },
    },
}
