local toolingLinkDefinition = import './tooling_link_definition.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testToolingLinkDefinitionNoDefaults: {
    actual: toolingLinkDefinition.toolingLinkDefinition()({
      url: 'https://gitlab.com/',
      title: 'GitLab',
    }),
    expect: {
      url: 'https://gitlab.com/',
      title: 'GitLab',
    },
  },
  testToolingLinkDefinitionDefaults: {
    actual: toolingLinkDefinition.toolingLinkDefinition({ title: 'GitLab' })({
      url: 'https://gitlab.com/',
    }),
    expect: {
      url: 'https://gitlab.com/',
      title: 'GitLab',
    },
  },
  testToolingLinkDefinitionDefaultsOverride: {
    actual: toolingLinkDefinition.toolingLinkDefinition({ title: 'GitLab' })({
      url: 'https://gitlab.com/',
      title: 'GitLab.com',
    }),
    expect: {
      url: 'https://gitlab.com/',
      title: 'GitLab.com',
    },
  },
})
