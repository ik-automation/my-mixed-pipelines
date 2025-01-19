{
  // Task for uilding docker-image
  dockerImage(name):: {
    tags: ['build'],
    stage: 'build',
    image: {
      name: 'gcr.io/kaniko-project/executor:debug-v0.15.0',
      entrypoint: [''],
    },
    script: [
      'echo "{\\"auths\\":{\\"$CI_REGISTRY\\":{\\"username\\":\\"$CI_REGISTRY_USER\\",\\"password\\":\\"$CI_REGISTRY_PASSWORD\\"}}}" > /kaniko/.docker/config.json',
      '/kaniko/executor --cache --context $CI_PROJECT_DIR/dockerfiles/' + name + ' --dockerfile $CI_PROJECT_DIR/dockerfiles/' + name + '/Dockerfile --destination $CI_REGISTRY_IMAGE/' + name + ':$CI_COMMIT_TAG --build-arg VERSION=$CI_COMMIT_TAG',
    ],
  },
  // Job for deploying qbec application
  qbecApp(name): {
    stage: 'deploy',
    script: [
      'qbec apply $CI_COMMIT_REF_NAME --root deploy/' + name + ' --force:k8s-context __incluster__ --wait --yes',
    ],
    only: {
      changes: [
        'deploy/' + name + '/**/*',
      ],
    },
  },
}
