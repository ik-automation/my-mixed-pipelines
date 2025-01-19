// https://mustafaakin.dev/posts/2020-04-26-using-jsonnet-to-generate-dynamic-tekton-pipelines-in-kubernetes/
// jsonnet multi.jsonnet
local tkn = import 'tekton.jsonnet';

local git = function(repo, branch)
  tkn.step(
    name='git-clone',
    // Always pin your versions in Docker images to avoid unnecessary pulls
    // You can achieve more security with sha256 pinning
    image='alpine/git:v2.24.2',
    // Single branch and depth=1 makees checking out much faster for large repos
    script='git clone %s --depth=1 --single-branch --branch %s .' % [repo, branch]
  );


local mvnTest = function(version)
  tkn.task(
    name='java-' + version,
    steps=[
        // My favorite Java library <3
      git('https://github.com/jhalterman/failsafe.git', 'master'),
      // Batch mode causes less output in Maven
      tkn.step(name='test', image='maven:' + version, script='mvn test -T1C --batch-mode'),
    ]
  );

local versions = [
  "3-jdk-8",
  "3-jdk-11",
  "3-jdk-14",
];

tkn.pipeline(
  name='java-test-jsonnet',
  tasks=[
    mvnTest(version)
    for version in versions
  ]
)
