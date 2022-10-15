local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local stableIds = import 'stable-ids.libsonnet';

test.suite({
  testBlank: { actual: stableIds.hashStableId(''), expect: 3558707393 },
  testHello: { actual: stableIds.hashStableId('hello'), expect: 1564558354 },
  testWithDashes: { actual: stableIds.hashStableId('collapsed-panel'), expect: 3457099265 },
})
