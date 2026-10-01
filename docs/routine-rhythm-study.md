# Routine rhythm study

Native SwiftUI DEBUG route: `--rhythm-study`. Isolated sample data; no generated artwork, health writes or notification scheduling.

## Representation

One narrow, softly squared stitch represents one scheduled occurrence, ordered chronologically over a four-day window. Today is accented; future occurrences are neutral outlined marks. Completion fills the stitch with a restrained warm-red material. Dates center under the occurrences they own, so two actions on one day occupy two stitches. The curve is decorative, not a value/trend axis. Tapping a stitch opens its named routine and due day.

The compact glass header contains a miniature strand and explicit today count. Primary rows remain opaque. Weight is weekdays, Stretch is daily, and meal planning is weekly on Sunday. The day selector switches Thursday through Sunday to reveal different schedules without manufacturing missed actions.

## Interaction

Weight opens a draft sheet; save commits the sample value/check-in, while Close discards pending edits. Non-weight Today rows toggle completion directly. Future occurrences show their next date. Both full and compact strands update from the same completion IDs. IDs include the occurrence day to avoid reusing a prior week's completion. Narrow layouts scroll the strand horizontally, preserving at least46pt non-overlapping touch targets. Reduce Motion suppresses explicit completion animation.

## Review

Initial capsules looked like pills and consumed too much height. Native capture review led to narrower squared stitches, shorter hero, centered day labels, a multi-stitch compact mark, and higher neutral-outline contrast. Independent review caught overlapping targets on narrow widths and unsaved weight edits; both were corrected.

The compact mark currently feels more convincing than the large hero. The large strand is still an abstract schedule illustration, so retain this as an experiment rather than treating it as the final Routine identity. Largest Dynamic Type and exhaustive VoiceOver interaction remain unverified.

Final focused UI test passed: /private/tmp/trai-rhythm-final.xcresult. Captures cover initial light state, completion, confirmed dark appearance, and Sunday schedule. Final captures: /private/tmp/trai-rhythm-final-captures. Sample day switching moves weekly meal planning into Today and weekday weight into Coming up.
