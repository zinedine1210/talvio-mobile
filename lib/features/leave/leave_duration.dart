/// Inclusive day count between two `YYYY-MM-DD` dates (a single-day leave
/// spans 1 day). Pure function — no I/O, easy to test. Note: the actual
/// start/end ordering guarantee comes from `showDateRangePicker` itself
/// (it never lets you pick an end before the start), so there's no
/// separate "is this range valid" validator to write here.
int leaveDurationDays(DateTime start, DateTime end) {
  return end.difference(start).inDays + 1;
}
