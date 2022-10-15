// https://mustafaakin.dev/posts/2020-04-26-using-jsonnet-to-generate-dynamic-tekton-pipelines-in-kubernetes/
{
  step: function(name, image, script) {
    name: name,
    image: image,
    script: script,
  },
  task: function(name, steps) {
    name: name,
    taskSpec: {
      steps: steps,
    },
  },
  pipeline: function(name, tasks) {
    apiVersion: 'tekton.dev/v1beta1',
    kind: 'PipelineRun',
    metadata: {
      name: name,
    },
    spec: {
      pipelineSpec: {
        tasks: tasks,
      },
    },
  },
}
