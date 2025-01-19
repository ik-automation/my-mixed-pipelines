// https://www.cresten.pizza/blog/2018-12-04-jsonnet-unit-testing/
# components/example.libsonnet
// Import KSonnet library
local k = import "k.libsonnet";

// Specify the import objects that we need
local container = k.extensions.v1beta1.deployment.mixin.spec.template.spec.containersType;
local depl = k.extensions.v1beta1.deployment;

// Define containers

local new(_env, _params) = (
local params = _env + _params.components.example;
  local containers = [
        container.new(params.name, params.image)
  ];

  local deployment =
      depl.new(params.name, params.replicas, containers, {app: params.name});
);


# tests/example_test.libsonnet
local componentToTest = import "./example.libsonnet";
local name = "example_name";
local image = "example_image";
local replicas = "3";
local instance = componentToTest.new({}, parmas);

local params = {
  components: {
    example: {
      name: name,
      image: image,
      replicas: replicas
    }
  }
};

local runTests(params) = (
  local testResults =
    // Check to ensure deployment name matches up
    std.assertEqual(instance.spec.metadata.name, name)
  testResults
);


{
  output: instance,
  results: runTests(params),
}
