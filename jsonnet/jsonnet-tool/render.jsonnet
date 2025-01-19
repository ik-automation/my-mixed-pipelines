// https://gitlab.com/gitlab-com/gl-infra/jsonnet-tool/-/blob/main/examples/render.jsonnet
// This file contains examples of output suitable for `jsonnet-tool render`
// Render is a flexible subcommand that allows multiple file outputs
// to be rendered from a single execution
local library = import "library.libsonnet";

{
  // YAML files do not need to use std.manifestYamlDoc
  // jsonnet-tool render will format them as YAML
  // The file will need a `.yaml` or `.yml` extension to be recognised
  // by `jsonnet-tool render`
  'moo.yaml': {
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
  },

  // jsonnet-tool render will also handle a pre-manifested string
  'moo2.yaml': std.manifestYamlDoc({
    moo2: true,
  }),

  // jsonnet-tool render will custom formats such as ini
  'file.ini': std.manifestIni({
    main: {
      a: 1,
    },
    sections: {
      foo: {
        a: true,
        b: 2,
      },
      bar: {
        x: 'text',
      },
    },
  }),

  // jsonnet-tool render will default to JSON output
  'file.json': {
    foo: {
      a: true,
      b: 2,
    },
  },
}
