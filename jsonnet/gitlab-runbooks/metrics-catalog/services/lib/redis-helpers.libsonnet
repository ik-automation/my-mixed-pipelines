local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

{
  // These tooling links are GitLab.com specific, so we don't put them into the archetype
  gitlabcomObservabilityToolingForRedis(redisType)::
    {
      serviceLevelIndicators+: {
        primary_server+: {
          toolingLinks+: [
            toolingLinks.kibana(title='Redis', index='redis', type=redisType),
            toolingLinks.kibana(title='Redis Slowlog', index='redis_slowlog', type=redisType),
          ],
        },
      },
    },
}
