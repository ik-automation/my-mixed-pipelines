{
  fromPairs(items):
    std.foldl(
      function(object, item)
        local key = '' + item[0];

        if std.objectHas(object, key) then object else object { [key]: item[1] },
      items,
      {}
    ),
  objectWithout(object, fieldToRemove):
    std.foldl(
      function(result, fieldName)
        if fieldName == fieldToRemove then
          result
        else if std.objectHas(object, fieldName) then
          result { [fieldName]: object[fieldName] }
        else
          result { [fieldName]:: object[fieldName] },
      std.objectFieldsAll(object),
      {},
    ),
  toPairs(object):
    std.map(
      function(key) [key, object[key]],
      std.objectFields(object)
    ),

  // Given an array of objects, merges them all into a single object
  // using a left-to-right merge order. Fields in later
  // objects will overwrite fields in earlier objects.
  mergeAll(arrayOfObjects)::
    std.foldl(
      function(memo, module)
        memo + module,
      arrayOfObjects,
      {}
    ),

  // Given an object, transform each key and value into another
  // object. The function should return a tuple of [key, value].
  // If the result is nil, the key-value pair is omitted.
  mapKeyValues(fn, object)::
    std.foldl(
      function(memo, key)
        local res = fn(key, object[key]);
        if res == null then
          memo
        else
          memo { [res[0]]: res[1] },
      std.objectFields(object),
      {}
    ),
}
