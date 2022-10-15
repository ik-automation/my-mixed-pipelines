{
  toSeconds(duration)::
    local durStr = std.substr(duration, 0, std.length(duration) - 1);
    local dur = std.parseInt(durStr);
    if std.endsWith(duration, 'w') then
      dur * 86400 * 7
    else if std.endsWith(duration, 'd') then
      dur * 86400
    else if std.endsWith(duration, 'h') then
      dur * 3600
    else if std.endsWith(duration, 'm') then
      dur * 60
    else if std.endsWith(duration, 's') then
      dur
    else
      dur,
}
