local patroniHelpers = import './lib/patroni-helpers.libsonnet';
local patroniArchetype = import 'service-archetypes/patroni-archetype.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  patroniArchetype(
    type='patroni-registry',
    serviceDependencies={
      patroni: true,
    },

    extraTags=[
      // postgres_fluent_csvlog_monitoring implies that this service is running fluent-csvlog with vacuum parsing.
      // In future, this should be something we can fold into postgres_with_primaries, but not all postgres instances
      // handle this at present.
      'postgres_fluent_csvlog_monitoring',
    ],
  )
  {
    skippedMaturityCriteria: maturityLevels.skip({
      'Developer guides exist in developer documentation': 'patroni is an infrastructure component, developers do not interact with it',
    }),
  }
  + patroniHelpers.gitlabcomObservabilityToolingForPatroni('patroni-registry')
)
