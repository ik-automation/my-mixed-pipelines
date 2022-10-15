// Import our library
local jobs = import 'lib/jobs.libsonnet';

// Define override functions
local ref(x) = { only+: { refs: [x] } };
local tag(x) = { tags: [x] };
local submodule(x) = { variables+: { GIT_SUBMODULE_STRATEGY: x } };

{
  // Building docker-images
  ['build:' + x]: jobs.dockerImage(x) + tag('build') + ref('tags')
  for x in [
    'dinner',
    'drunk',
    'fanatical',
    'guarantee',
    'guitar',
    'harmonious',
    'shop',
    'smelly',
    'thunder',
    'yarn',
  ]
}
+
{
  // Deploy applications that should be deployed only in 'prod'
  ['deploy:prod:' + x]: jobs.qbecApp(x) + tag('prod') + ref('prod')
  for x in [
    'dinner',
    'hall',
  ]
}
+
{
  // Deploy with git-submodule
  ['deploy:' + env + ':' + app]: jobs.qbecApp(app) + tag(env) + ref(env) + submodule('normal')
  for env in ['devel', 'stage', 'prod']
  for app in [
    'brush',
    'fanatical',
    'history',
    'shop',
  ]
}
+
{
  // Deploy the rest
  ['deploy:' + env + ':' + app]: jobs.qbecApp(app) + tag(env) + ref(env)
  for env in ['devel', 'stage', 'prod']
  for app in [
    'analyse',
    'basin',
    'copper',
    'dirty',
    'drab',
    'drunk',
    'education',
    'faulty',
    'guarantee',
    'guitar',
    'harmonious',
    'iron',
    'maniacal',
    'mist',
    'nine',
    'pleasant',
    'polish',
    'receipt',
    'smelly',
    'solid',
    'stroke',
    'thunder',
    'ultra',
    'yarn',
  ]
}
