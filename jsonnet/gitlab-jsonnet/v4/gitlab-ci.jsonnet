// jsonnet gitlab-ci.jsonnet > generated-config.yml
local job(thing) =
  {
    image: "alpine:latest",
    stage: "deploy",
    script: "echo I LIKE " + thing
  };

local things = ['blue', 'red', 'green', 'foxes', 'cats', 'goats'];
{
  ['job/' + x]: job(x)
  for x in things
}
