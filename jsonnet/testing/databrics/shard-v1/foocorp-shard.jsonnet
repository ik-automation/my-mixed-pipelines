local shardTemplate = import "TEMPLATE.shard.jsonnet";

shardTemplate + {
  customerName:: "foocorp",
  release:: "2.42-rc1",
}
