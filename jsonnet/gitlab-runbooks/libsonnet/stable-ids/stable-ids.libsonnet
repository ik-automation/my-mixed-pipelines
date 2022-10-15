{
  hashStableId(stableId)::
    if std.isString(stableId) then
      1000 + (std.parseHex(std.md5(stableId)[:8]))
    else
      std.assertEqual(stableId, { __assert: 'stableId must be a string, got ' + stableId }),
}
