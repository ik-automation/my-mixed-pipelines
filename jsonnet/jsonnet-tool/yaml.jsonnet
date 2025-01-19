// https://gitlab.com/gitlab-com/gl-infra/jsonnet-tool/-/blob/main/examples/yaml.jsonnet
// This file contains examples of output suitable for `jsonnet-tool yaml`
// `jsonnet-tool yaml` will emit formatted YAML from a Jsonnet input
local library = import "library.libsonnet";

{
  'moo.yaml': std.manifestYamlDoc({
    hello: true,
    there: 1,
    library: library,
    moo: {
      there: 1,
      hello: true,
    },
    list: [1, 2, 3],
    listOfObjects: [
      {
        hello: true,
        there: 1,
      },
      {
        a: true,
        b: 1,
        c: 2,
        there: 1,
      },
    ],
  }),
}
