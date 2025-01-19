// https://mustafaakin.dev/posts/2020-04-26-using-jsonnet-to-generate-dynamic-tekton-pipelines-in-kubernetes/
// jsonnet example.jsonnet
local tkn = import 'tekton.jsonnet';

local task1 = tkn.task(name='task-1', steps=[
  tkn.step('compile', 'ubuntu', "echo 'Compling beep boop...'"),
  tkn.step('tests', 'ubuntu', "echo 'Compiled, running tests...'"),
]);

local task2 = tkn.task(name='task-2', steps=[
  tkn.step('run', 'ubuntu', "echo 'This is another Pod!'"),
]);

tkn.pipeline(name='embed-test-jsonnet', tasks=[task1, task2])
