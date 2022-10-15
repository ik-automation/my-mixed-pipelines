// https://shinglyu.com/devops/2019/02/28/simplify-your-ci-pipeline-configuration-with-jsonnet.html
// jsonnet demo.jsonnet
local build = {
  name: 'build',
  image: 'node:8.6.0',
  commands: [
    'npm install',
    'npm run build',
  ],
};

local unitTest = {
  name: 'unit_test',
  image: 'node:8.6.0',
  commands: [
    'npm run unit_test',
  ],
};

local integrationTest = {
  name: 'integration_test',
  image: 'node:8.6.0',
  commands: [
    'npm run integration_test',
  ],
};

local deploy(env, region) =
{
  name: 'deploy_%(env)s_%(region)s' % { env: env, region: region },
  image: 'node:8.6.0',
  commands: [
    'npm run deploy -- --env=%(env)s --region=%(region)s' % { env: env, region: region },
  ],
};

local commitToNonMasterSteps = [
  build,
  unitTest
];

local whenCommitToNonMaster(step) = step {
  when: {
    event: ['push'],
    branch: {
      exclude: ['master'],
    },
  },
};

local commitToNonMasterSteps = std.map(whenCommitToNonMaster, [
  build,
  unitTest,
]);

local whenMergeToMaster(step) = step {
  when: {
    event: ['push'],
    branch: ['master'],
  },
};

local mergeToMasterSteps = std.map(whenMergeToMaster, [
  build,
  unitTest,
  deploy('dev', 'eu-central-1'),
  deploy('dev', 'us-west-1'),
  integrationTest,
]);

local pipelines = std.flattenArrays([
  commitToNonMasterSteps, // build, unitTest
  mergeToMasterSteps,      // build, unitTest, deploy_dev_eu,   deploy_dev_us,   integrationTest
  // deployToStageSteps,     //                  deploy_stage_eu, deploy_stage_us, integrationTest
  // deployToProdSteps,      //                  deploy_prod_eu,  deploy_prod_us,  integrationTest
]);

// Below is the actual JSON object that will be emitted by the jsonnet compiler.
{
  kind: 'pipeline',
  name: 'default',
  steps: pipelines,
}

