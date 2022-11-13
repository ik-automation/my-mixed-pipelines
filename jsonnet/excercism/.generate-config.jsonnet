// https://gitlab.com/EmilienMottet/exercism-sol/-/blob/master/c/.generate-config.jsonnet
local exercism_projects = std.map(function(x) std.strReplace(x, '/', ''), std.split(std.extVar('exercism_projects'), '\n'));
local lang = std.extVar('lang');

local JobHandler(name) = {
  ['test_' + lang + '_' + name]: {
    stage: 'test',
    trigger: {
      include: [
        {
          artifact: '.' + lang + '-' + name + '-gitlab-ci.yml',
          job: 'generate_' + lang + '_gitlab_ci',
        },
      ],
      strategy: 'depend',
    },
  },
};

{
  '.generated-config.yml': { ['generate_' + lang + '_gitlab_ci']: {
    stage: 'build',
    image: {
      name: 'bitnami/jsonnet:latest',
      entrypoint: [''],
    },
    script: [
      'DIR_SPLIT=$(echo $DIR_TO_BE_TESTED | tr " " "\n")',
      'jsonnet -m . --ext-str exercism_projects="$DIR_SPLIT" --ext-str lang="' + lang + '" ".' + lang + '-gitlab-ci.jsonnet"',
    ],
    needs: [
      {
        pipeline: '$PARENT_PIPELINE_ID',
        job: 'build_vars',
      },
    ],


    artifacts: {
      paths: [
        '.' + lang + '-*-gitlab-ci.yml',
      ],
    },
  } } + std.foldl(function(x, y) x + y, std.map(JobHandler, exercism_projects), {}),
}
