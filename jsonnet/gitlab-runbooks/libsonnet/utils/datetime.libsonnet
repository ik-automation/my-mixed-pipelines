local new(dateStr) =
  {
    date: std.split(dateStr, 'T')[0],
    timezone:
      if std.endsWith(dateStr, 'Z') then
        'Z'
      else
        local size = std.length(dateStr);
        std.substr(dateStr, size - 6, size),

    beginningOfDay:
      new('%sT00:00:00%s' % [self.date, self.timezone]),

    toString:
      dateStr,
  };

{
  // Takes an RFC3339 time as used in prometheus
  new(dateStr):: new(dateStr),

}
