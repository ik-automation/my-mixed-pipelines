local underTest = import './label-taxonomy.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local l = underTest.labels;

test.suite({
  testLabelTaxonomyEmpty: {
    actual: underTest.labelTaxonomy(l.empty),
    expect: [],
  },

  testLabelTaxonomyBasic: {
    actual: underTest.labelTaxonomy(l.environment),
    expect: ['environment'],
  },

  testLabelTaxonomyAll: {
    actual: underTest.labelTaxonomy(l.environmentThanos | l.environment | l.tier | l.service | l.stage | l.shard | l.node),
    expect: ['env', 'environment', 'tier', 'type', 'stage', 'shard', 'fqdn'],
  },

  testLabelTaxonomySerialized: {
    actual: underTest.labelTaxonomySerialized(l.stage | l.shard | l.node),
    expect: 'stage,shard,fqdn',
  },

  testGetLabelFor: {
    actual: underTest.getLabelFor(l.stage),
    expect: 'stage',
  },

  testLabelTaxonomyComponent: {
    actual: underTest.labelTaxonomy(l.sliComponent),
    expect: ['component'],
  },

  testHasLabelFor: {
    actual: underTest.hasLabelFor(l.sliComponent),
    expect: true,
  },
})
