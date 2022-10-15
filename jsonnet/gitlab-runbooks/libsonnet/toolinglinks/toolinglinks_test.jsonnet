local toolinglinks = import './toolinglinks.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testGenerateMarkdownBlank: {
    actual: toolinglinks.generateMarkdown([
    ]),
    expect: '',
  },
  testGenerateMarkdownSingle: {
    actual: toolinglinks.generateMarkdown([
      function(options) [{ url: 'https://gitlab.com', title: 'GitLab.com' }],
    ]),
    expect: |||
      * [GitLab.com](https://gitlab.com)
    |||,
  },
  testGenerateMarkdownMultiple: {
    actual: toolinglinks.generateMarkdown([
      function(options) [{ url: 'https://gitlab.com', title: 'GitLab.com' }],
      function(options) [{ url: 'https://dev.gitlab.org', title: 'dev.GitLab.com' }],
    ]),
    expect: |||
      * [GitLab.com](https://gitlab.com)
      * [dev.GitLab.com](https://dev.gitlab.org)
    |||,
  },

})
