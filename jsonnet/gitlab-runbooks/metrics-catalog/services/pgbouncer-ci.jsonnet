local pgbouncerHelpers = import './lib/pgbouncer-helpers.libsonnet';
local pgbouncerArchetype = import 'service-archetypes/pgbouncer-archetype.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  pgbouncerArchetype(
    type='pgbouncer-ci',
    extraTags=[
      'pgbouncer_async_primary',
    ],
  )
  {
    serviceDependencies: {
      'patroni-ci': true,
    },
    skippedMaturityCriteria: maturityLevels.skip({
      'Developer guides exist in developer documentation': 'pgbouncer is an infrastructure component, developers do not interact with it',
    }),
  }
  + pgbouncerHelpers.gitlabcomObservabilityToolingForPgbouncer('pgbouncer-ci')
)
