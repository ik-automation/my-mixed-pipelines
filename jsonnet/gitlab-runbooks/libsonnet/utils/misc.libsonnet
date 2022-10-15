// Like Rails's #present? (nulls, false, and empty are not present), but
// allows nulls to either return `false` or `null`.
local isPresent(object, nullValue=false) =
  if object == null then
    nullValue
  else if std.isBoolean(object) then
    object
  else
    std.length(object) > 0;

local all(func, collection) =
  std.foldl(function(accumulator, item) accumulator && func(item), collection, true);

local any(func, collection) =
  std.foldl(function(accumulator, item) accumulator || func(item), collection, false);

local dig(object, keys) =
  std.foldl(
    function(accumulator, key) if std.objectHas(accumulator, key) then accumulator[key] else {},
    keys,
    object
  );

local occurences(array) = std.foldl(
  function(hash, item)
    if !std.objectHas(hash, item) then hash { [item]: 1 } else hash { [item]: hash[item] + 1 },
  array,
  {}
);

// Return an array consisting of members in array1 but not in array2
// Equivalent to arr1 - arr2 in Ruby
local arrayDiff(arr1, arr2) =
  local hash1 = occurences(arr1);
  local hash2 = occurences(arr2);
  std.foldl(
    function(diff, field)
      diff +
      if std.objectHas(hash2, field) then
        local num = hash1[field] - hash2[field];
        std.repeat([field], if num < 1 then 0 else num)
      else
        std.repeat([field], hash1[field]),
    std.objectFields(hash1),
    []
  );

local digHas(object, keys) = dig(object, keys) != {};

local objectIncludes(underTest, other) =
  local expectedKeys = std.objectFields(other);
  all(
    function(expectedKey)
      std.objectHas(underTest, expectedKey) && underTest[expectedKey] == other[expectedKey],
    expectedKeys
  );

{
  all: all,
  any: any,
  isPresent: isPresent,
  dig: dig,
  digHas: digHas,
  arrayDiff: arrayDiff,
  objectIncludes: objectIncludes,
}
