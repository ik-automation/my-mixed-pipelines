// https://dev.to/emilienmottet/a-journey-into-the-depths-of-gitlab-ci-15j5
local exercism_projects = std.map(function(x) std.strReplace(x, '/', ''), std.split(std.extVar('exercism_projects'), '\n'));
local lang = std.extVar('lang');

local CTestJob(name) = {
  ['.' + lang + '-' + name + '-gitlab-ci.yml']: {
    default: {
      image: 'gcc:latest',
    },
    ['test-' + lang + '-' + name + '-exercism']: {
      script: [
        'cd ' + name,
        'make',
      ],
    },
  },
};


std.foldl(function(x, y) x + y, std.map(CTestJob, exercism_projects), {})
