local shardTemplate = import "TEMPLATE.shard.jsonnet";
local devEnv = import "dev-env.json";

local newDevShard(shardName, release="bleeding-edge") = (
  shardTemplate.newShard(shardName, release, env=devEnv)
);

{
  newDevShard:: newDevShard,
}
