// https://tanka.dev/helm
local tanka = import "github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet";
local helm = tanka.helm.new(std.thisFile);

{
  grafana: helm.template("grafana", "./charts/grafana", {
    namespace: "monitoring",
    values: {
      persistence: { enabled: true }
    }
  })
}
