local sentry = import './sentry.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testSentryPlain: {
    actual: sentry.sentry('gitlab/gitlabcom', variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases: gitlab/gitlabcom',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases?environment=${environment}',
      },
      {
        title: '🐞 Sentry issues',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=stage%3A${stage}',
      },
    ],
  },
  testSentryType: {
    actual: sentry.sentry('gitlab/gitlabcom', type='sidekiq', variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases: gitlab/gitlabcom',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases?environment=${environment}',
      },
      {
        title: '🐞 Sentry sidekiq issues',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=stage%3A${stage}+type%3Asidekiq',
      },
    ],
  },
  testSentryFeatureCatagories: {
    actual: sentry.sentry('gitlab/gitlabcom', featureCategories=['subgroups', 'users'], variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases: gitlab/gitlabcom',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases?environment=${environment}',
      },
      {
        title: '🐞 Sentry issues: subgroups',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Asubgroups+stage%3A${stage}',
      },
      {
        title: '🐞 Sentry issues: users',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Ausers+stage%3A${stage}',
      },
    ],
  },
  testSentryTypeAndFeatureCatagories: {
    actual: sentry.sentry('gitlab/gitlabcom', type='web', featureCategories=['subgroups', 'users'], variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases: gitlab/gitlabcom',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases?environment=${environment}',
      },
      {
        title: '🐞 Sentry web issues: subgroups',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Asubgroups+stage%3A${stage}+type%3Aweb',
      },
      {
        title: '🐞 Sentry web issues: users',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Ausers+stage%3A${stage}+type%3Aweb',
      },
    ],
  },
  testSentryTypeAndFeatureCatagoriesDefaultVariables: {
    actual: sentry.sentry('gitlab/gitlabcom', type='web', featureCategories=['subgroups', 'users'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases: gitlab/gitlabcom',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases?environment=${environment}',
      },
      {
        title: '🐞 Sentry web issues: subgroups',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Asubgroups+type%3Aweb',
      },
      {
        title: '🐞 Sentry web issues: users',
        url: 'https://sentry.gitlab.net/gitlab/gitlabcom/issues?environment=${environment}&query=feature_category%3Ausers+type%3Aweb',
      },
    ],
  },
})
