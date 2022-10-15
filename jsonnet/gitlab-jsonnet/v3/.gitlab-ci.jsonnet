// https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/tanka-deployments/-/blob/master/.gitlab-ci.jsonnet
local stages = {
  stages: [
    'notify',
    'build_ci_image',
    'checks',
    'diff',
    'apply',
  ],
};

local includes = {
  include: [
    // Dependency scanning
    // https://docs.gitlab.com/ee/user/application_security/dependency_scanning/
    { template: 'Security/Dependency-Scanning.gitlab-ci.yml' },
  ],
};

local variables = {
  variables: {
    VAULT_AUTH_PATH: 'ops-gitlab-net',
    VAULT_AUTH_ROLE: 'tanka-deployments',
    VAULT_SERVER_URL: 'https://vault.ops.gke.gitlab.net',
  },
};

// Prevent duplicate detached merge request pipelines from being created
// https://docs.gitlab.com/ee/ci/yaml/README.html#prevent-duplicate-pipelines
local workflow = {
  workflow: {
    rules: [
      {
        'if': '$CI_PIPELINE_SOURCE == "merge_request_event"',
        when: 'never',
      },
      {
        when: 'always',
      },
    ],
  },
};

local mainRegion = 'us-east1';

local clusterAttrs = {
  pre: {
    GOOGLE_PROJECT: 'gitlab-pre',
    GKE_CLUSTER: 'pre-gitlab-gke',
    GOOGLE_REGION: mainRegion,
  },

  gstg: {
    GOOGLE_PROJECT: 'gitlab-staging-1',
    GKE_CLUSTER: 'gstg-gitlab-gke',
    GOOGLE_REGION: mainRegion,
  },
  'gstg-us-east1-b': {
    ENVIRONMENT: 'gstg',
    GOOGLE_PROJECT: 'gitlab-staging-1',
    GKE_CLUSTER: 'gstg-us-east1-b',
    GOOGLE_ZONE: 'us-east1-b',
  },
  'gstg-us-east1-c': {
    ENVIRONMENT: 'gstg',
    GOOGLE_PROJECT: 'gitlab-staging-1',
    GKE_CLUSTER: 'gstg-us-east1-c',
    GOOGLE_ZONE: 'us-east1-c',
  },
  'gstg-us-east1-d': {
    ENVIRONMENT: 'gstg',
    GOOGLE_PROJECT: 'gitlab-staging-1',
    GKE_CLUSTER: 'gstg-us-east1-d',
    GOOGLE_ZONE: 'us-east1-d',
  },

  gprd: {
    GOOGLE_PROJECT: 'gitlab-production',
    GKE_CLUSTER: 'gprd-gitlab-gke',
    GOOGLE_REGION: mainRegion,
  },
  'gprd-us-east1-b': {
    ENVIRONMENT: 'gprd',
    GOOGLE_PROJECT: 'gitlab-production',
    GKE_CLUSTER: 'gprd-us-east1-b',
    GOOGLE_ZONE: 'us-east1-b',
  },
  'gprd-us-east1-c': {
    ENVIRONMENT: 'gprd',
    GOOGLE_PROJECT: 'gitlab-production',
    GKE_CLUSTER: 'gprd-us-east1-c',
    GOOGLE_ZONE: 'us-east1-c',
  },
  'gprd-us-east1-d': {
    ENVIRONMENT: 'gprd',
    GOOGLE_PROJECT: 'gitlab-production',
    GKE_CLUSTER: 'gprd-us-east1-d',
    GOOGLE_ZONE: 'us-east1-d',
  },

  ops: {
    GOOGLE_PROJECT: 'gitlab-ops',
    GKE_CLUSTER: 'ops-gitlab-gke',
    GOOGLE_REGION: mainRegion,
  },
  'ops-stg': self.ops {
    ENVIRONMENT: 'ops',
  },
  prdsub: {
    GOOGLE_PROJECT: 'gitlab-subscriptions-prod',
    GKE_CLUSTER: 'prdsub-customers-gke',
    GOOGLE_REGION: mainRegion,
  },
  stgsub: {
    GOOGLE_PROJECT: 'gitlab-subscriptions-staging',
    GKE_CLUSTER: 'stgsub-customers-gke',
    GOOGLE_REGION: mainRegion,
  },
};

local ruleEnableDeployments = '$TANKA_DEPLOYMENTS_RUN == "1"';
local ruleOutsideDeploymentPipeline = '$TANKA_DEPLOYMENTS_RUN == null';
local ruleOnMaster = '$CI_COMMIT_BRANCH == "master"';

local ruleAnd(rule) =
  ' && %s' % rule;

local ruleOr(rule) =
  ' || %s' % rule;

local ruleChanges(changes) =
  { changes: changes };

local tankaInlineJobs(software, cluster, tkExternalVars={}, tkTopLevelArgs={}, tkExtraArgs=[], extraVars={}, diffNotes='') =
  local envDir = 'environments/%s' % software;
  local envName = '%s/%s' % [software, cluster];

  local tkArgs = std.join(
    ' ',
    ['--ext-str %s="${%s}"' % [name, tkExternalVars[name]] for name in std.objectFields(tkExternalVars)]
    + ['--tla-str %s="${%s}"' % [name, tkTopLevelArgs[name]] for name in std.objectFields(tkTopLevelArgs)]
    + tkExtraArgs
  );

  // Run jobs for this environment when the environment changes, but also when
  // any of the generic code changes: lib, jsonnet-bundler deps, CI config. Err
  // on the side of running jobs when something has changed that they might
  // depend on.
  local envChanged = ruleChanges(['%s/*' % envDir, 'lib/**/*', 'jsonnetfile.*', '.gitlab-ci.yml', 'Dockerfile', 'charts/**/*']);

  local baseJob = {
    image: '${CI_REGISTRY_IMAGE}/ci:latest',

    secrets: {
      GOOGLE_APPLICATION_CREDENTIALS: {
        vault: 'ops-gitlab-net/tanka-deployments/shared/google-credentials/${ENVIRONMENT}/key@ci',
        file: true,
      },
    },

    // run on ops runners with access to our cluster VPCs
    tags: ['k8s-workloads'],

    variables:
      {
        ENVIRONMENT: cluster,
      }
      + clusterAttrs[cluster]
      + extraVars,
  };
  {
    ['%s:%s:diff' % [software, cluster]]: baseJob {
      stage: 'diff',
      script: |||
        ./bin/kubectl_login
        make vendor

        tk diff --diff-strategy validate --with-prune --exit-zero %(envDir)s --name %(envName)s %(tkArgs)s | colordiff
        echo -e "\033[0;31m%(diffNotes)s\033[0m"
      ||| % {
        envDir: envDir,
        envName: envName,
        tkArgs: tkArgs,
        diffNotes: diffNotes,
      },
      rules: [
        { 'if': ruleEnableDeployments } + envChanged,
        { 'if': '$TANKA_DEPLOYMENTS_RUN == "%s"' % envName },
      ],
    },

    ['%s:%s:apply' % [software, cluster]]: baseJob {
      stage: 'apply',
      needs: ['%s:%s:diff' % [software, cluster]],
      environment: envName,
      resource_group: envName,
      script: |||
        ./bin/kubectl_login
        make vendor
        tk apply --dangerous-auto-approve %(envDir)s --name %(envName)s %(tkArgs)s | colordiff
        tk prune --dangerous-auto-approve %(envDir)s --name %(envName)s %(tkArgs)s | colordiff
      ||| % {
        envDir: envDir,
        envName: envName,
        tkArgs: tkArgs,
      },
      rules: [
        { 'if': ruleEnableDeployments + ruleAnd(ruleOnMaster) } + envChanged,
        { 'if': '$TANKA_DEPLOYMENTS_RUN == "%s"' % envName },
      ],
    },
  };

local tankaStaticJobs(software, cluster, tkExternalVars={}, tkTopLevelArgs={}, tkExtraArgs=[], extraVars={}, diffNotes='') =
  local envSlug = '%s-%s' % [software, cluster];
  local envDir = 'environments/%s/%s' % [software, cluster];

  local tkArgs = std.join(
    ' ',
    ['--ext-str %s="${%s}"' % [name, tkExternalVars[name]] for name in std.objectFields(tkExternalVars)]
    + ['--tla-str %s="${%s}"' % [name, tkTopLevelArgs[name]] for name in std.objectFields(tkTopLevelArgs)]
    + tkExtraArgs
  );

  // Run jobs for this environment when the environment changes, but also when
  // any of the generic code changes: lib, jsonnet-bundler deps, CI config. Err
  // on the side of running jobs when something has changed that they might
  // depend on.
  local envChanged = ruleChanges(['%s/*' % envDir, 'lib/**/*', 'jsonnetfile.*', '.gitlab-ci.yml', 'Dockerfile', 'charts/**/*']);

  local baseJob = {
    image: '${CI_REGISTRY_IMAGE}/ci:latest',

    secrets: {
      GOOGLE_APPLICATION_CREDENTIALS: {
        vault: 'ops-gitlab-net/tanka-deployments/shared/google-credentials/${ENVIRONMENT}/key@ci',
        file: true,
      },
    },

    // run on ops runners with access to our cluster VPCs
    tags: ['k8s-workloads'],

    variables:
      {
        ENVIRONMENT: cluster,
        TANKA_ENV: envDir,
      }
      + clusterAttrs[cluster]
      + extraVars,
  };

  // Rules clauses can be a lttle hard to read. Each rule in the array is OR'ed:
  // if any pass, the job will run according to that rule's "when" value. Within
  // each rule, the various clauses ('if', 'changes') are AND'ed. In this way
  // it's possible to express complex rules such as "if $FOO is set and the
  // branch is master, run the job with manual gating - but if $BAR is set, run
  // it automatically with no manual intervention."
  //
  // Read the generated rules carefully, until you are sure what effect they
  // will have in a CI pipeline - even a branch run.
  //
  // https://docs.gitlab.com/ee/ci/yaml/
  {
    ['%s:%s:diff' % [software, cluster]]: baseJob {
      stage: 'diff',
      script: |||
        ./bin/kubectl_login
        make vendor

        tk diff --diff-strategy validate --with-prune --exit-zero "${TANKA_ENV}" %(tkArgs)s | colordiff
        echo -e "\033[0;31m%(diffNotes)s\033[0m"
      ||| % { tkArgs: tkArgs, diffNotes: diffNotes },
      rules: [
        { 'if': ruleEnableDeployments } + envChanged,
        { 'if': '$TANKA_DEPLOYMENTS_RUN == "%s"' % envSlug },
      ],
    },

    // The apply job has an extra rule that allows environments to be deployed
    // without manual intervention. This is designed for auto-deploy pipelines
    // in other repositories, that could trigger a tanka-deployments pipeline
    // via the API, passing in the env slug and also possibly other vars such as
    // Docker image tags.
    // This job has a rule that allows environments to be deployed without
    // manual intervention, but is not run in "normal" commit-triggered
    // pipelines where we set TANKA_DEPLOYMENTS_RUN=1. This is designed for
    // auto-deploy pipelines in other repositories, that could trigger a
    // tanka-deployments pipeline via the API, passing in the env slug and also
    // possibly other vars such as Docker image tags.
    // We must split it from the regular apply job to avoid using a "needs"
    // keyword that references jobs that won't be instantiated in such
    // pipelines.
    // If the only thing being bumped is an image tag, there is less benefit in
    // reviewing tanka diffs - the code change has already been approved. This
    // is in contrast with modifications to the tanka manifests themselves,
    // which should always be reviewed.
    ['%s:%s:apply' % [software, cluster]]: baseJob {
      stage: 'apply',
      needs: ['%s:%s:diff' % [software, cluster]],
      environment: envSlug,
      resource_group: envSlug,
      script: |||
        ./bin/kubectl_login
        make vendor
        tk apply --dangerous-auto-approve "${TANKA_ENV}" %(tkArgs)s | colordiff
        tk prune --dangerous-auto-approve "${TANKA_ENV}" %(tkArgs)s | colordiff
      ||| % { tkArgs: tkArgs },
      rules: [
        { 'if': ruleEnableDeployments + ruleAnd(ruleOnMaster) } + envChanged,
        { 'if': '$TANKA_DEPLOYMENTS_RUN == "%s"' % envSlug },
      ],
    },
  };

local buildCIDockerImageJob = {
  build_ci_docker_image: {
    stage: 'build_ci_image',
    image: 'docker:stable',
    services: ['docker:dind'],
    script: |||
      docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
      tag="${CI_REGISTRY_IMAGE}/ci:latest"
      docker build -t "${tag}" .
      docker push "${tag}"
    |||,
    rules: [
      // Run this job on master commits but not when TANKA_DEPLOYMENTS_RUN is
      // set to some value other than "1" - basically, don't run this job when
      // we're in an API-triggered pipelined intended to auto-deploy one thing.
      // Alternatively, run this job when BUILD_CI_IMAGE is set to 1, which
      // only happens in manually triggered pipelines and in any case not often.
      { 'if': ruleOnMaster + ruleAnd('(%s)' % (ruleEnableDeployments + ruleOr(ruleOutsideDeploymentPipeline))) }
      + ruleChanges(['Dockerfile', '.tool-versions', 'bin/install_tools']),
      { 'if': '$BUILD_CI_IMAGE == "1"' },
    ],
  },
};

local notifyMirrorSourceMR = {
  notify_mirror_source: {
    stage: 'notify',
    image: 'registry.gitlab.com/gitlab-com/gl-infra/woodhouse:latest',
    script: 'woodhouse gitlab notify-mirrored-mr',
    rules: [
      { 'if': ruleEnableDeployments },
    ],
  },
};

local assertFormatting = {
  assert_formatting: {
    stage: 'checks',
    image: '${CI_REGISTRY_IMAGE}/ci:latest',
    script: |||
      find . -name '*.*sonnet' | xargs -n1 jsonnetfmt -i
      git diff --exit-code
    |||,
    rules: [
      { 'if': ruleEnableDeployments + ruleOr(ruleOutsideDeploymentPipeline) },
    ],
  },
};

local ciConfigGenerated = {
  ci_config_generated: {
    stage: 'checks',
    image: '${CI_REGISTRY_IMAGE}/ci:latest',
    script: |||
      make generate-ci-config
      git diff --exit-code || (echo "Please run 'make generate-ci-config'" >&2 && exit 1)
    |||,
    rules: [
      { 'if': ruleEnableDeployments + ruleOr(ruleOutsideDeploymentPipeline) },
    ],
  },
};

local ensureVendoredCharts = {
  ensure_vendored_charts: {
    stage: 'checks',
    image: '${CI_REGISTRY_IMAGE}/ci:latest',
    script: |||
      make ensure-vendored-charts
    |||,
    rules: [
      { 'if': ruleEnableDeployments + ruleOr(ruleOutsideDeploymentPipeline) },
    ],
  },
};

local apiTriggeredDiffNotes = |||
  !!! Attention !!!
  This environment is often applied via API-triggered pipelines that override
  the image tag. If you're seeing a diff in that field, that's probably why. It
  should be safe to deploy the "latest" tag, due to ImagePullPolicy=Always.
  !!! Attention !!!
|||;

local dependencyScanning = {
  dependency_scanning: {
    stage: 'checks',
  },
};

local gitlabCIConf =
  stages
  + includes
  + variables
  + workflow
  + notifyMirrorSourceMR
  + assertFormatting
  + ciConfigGenerated
  + ensureVendoredCharts
  + dependencyScanning

  + tankaInlineJobs('fluentd-archiver', 'pre')
  + tankaInlineJobs('fluentd-archiver', 'gstg')
  + tankaInlineJobs('fluentd-archiver', 'gprd')
  + tankaInlineJobs('fluentd-archiver', 'ops')

  + tankaInlineJobs('thanos', 'pre')
  + tankaInlineJobs('thanos', 'gstg')
  + tankaInlineJobs('thanos', 'gprd')
  + tankaInlineJobs('thanos', 'prdsub')
  + tankaInlineJobs('thanos', 'stgsub')
  + tankaInlineJobs('thanos', 'ops')
  + tankaInlineJobs('thanos', 'ops-stg')

  + tankaInlineJobs('redis', 'pre')
  + tankaInlineJobs('redis', 'gstg')

  + tankaInlineJobs(
    'delivery-metrics',
    'ops',
    tkTopLevelArgs={ tag: 'DELIVERY_METRICS_TAG' },
    extraVars={ DELIVERY_METRICS_TAG: 'latest' },
    diffNotes=apiTriggeredDiffNotes,
  )

  + tankaInlineJobs(
    'woodhouse',
    'gstg',
    tkTopLevelArgs={ tag: 'WOODHOUSE_TAG' },
    extraVars={ WOODHOUSE_TAG: 'latest' },
    diffNotes=apiTriggeredDiffNotes,
  )

  + tankaInlineJobs(
    'woodhouse',
    'ops',
    tkTopLevelArgs={ tag: 'WOODHOUSE_TAG' },
    extraVars={ WOODHOUSE_TAG: 'latest' },
    diffNotes=apiTriggeredDiffNotes,
  )

  + tankaInlineJobs('evicted-pod-reaper', 'gprd')

  + tankaInlineJobs('elastic', 'gstg')

  + tankaInlineJobs('gcp-quota-exporter', 'ops')
  + tankaInlineJobs('gcp-quota-exporter', 'pre')
  + tankaInlineJobs('gcp-quota-exporter', 'gstg')
  + tankaInlineJobs('gcp-quota-exporter', 'gprd')

  + tankaInlineJobs('plantuml', 'pre')
  + tankaInlineJobs('plantuml', 'gstg')
  + tankaInlineJobs('plantuml', 'gprd')

  + tankaInlineJobs('fluentd-elasticsearch', 'pre')
  + tankaInlineJobs('fluentd-elasticsearch', 'ops')
  + tankaInlineJobs('fluentd-elasticsearch', 'gstg')
  + tankaInlineJobs('fluentd-elasticsearch', 'gstg-us-east1-b')
  + tankaInlineJobs('fluentd-elasticsearch', 'gstg-us-east1-c')
  + tankaInlineJobs('fluentd-elasticsearch', 'gstg-us-east1-d')
  + tankaInlineJobs('fluentd-elasticsearch', 'gprd')
  + tankaInlineJobs('fluentd-elasticsearch', 'gprd-us-east1-b')
  + tankaInlineJobs('fluentd-elasticsearch', 'gprd-us-east1-c')
  + tankaInlineJobs('fluentd-elasticsearch', 'gprd-us-east1-d')
  + tankaInlineJobs('grafana', 'pre')
  + tankaInlineJobs('grafana', 'ops')

  + buildCIDockerImageJob;

std.manifestYamlDoc(gitlabCIConf)
