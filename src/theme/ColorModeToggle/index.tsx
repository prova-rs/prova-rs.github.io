import React, {type ReactNode} from 'react';
import ColorModeToggle from '@theme-original/ColorModeToggle';
import type ColorModeToggleType from '@theme/ColorModeToggle';
import type {WrapperProps} from '@docusaurus/types';
import {useColorMode} from '@docusaurus/theme-common';

type Props = WrapperProps<typeof ColorModeToggleType>;

/**
 * Makes the color-mode toggle a two-state flip: passing <-> failing.
 *
 * Docusaurus cycles null(system) -> light -> dark -> null when
 * respectPrefersColorScheme is on. The system step renders identically to
 * whichever explicit mode matches the reader's OS, so one click in three
 * changes nothing on screen — tolerable when the two themes were both green,
 * jarring now that the click is supposed to flip the verdict.
 *
 * The upstream toggle decides the next mode from two props, and both are ours
 * to set: `value` (it cycles from this) and `respectPrefersColorScheme` (it
 * picks the 2- or 3-value cycle from this). Feeding it the RESOLVED color mode
 * plus a forced `false` yields "flip to the opposite of what you're looking
 * at" — never landing on system, so there is no dead click, not even the first
 * one from a system-mode start.
 *
 * The provider reads respectPrefersColorScheme from themeConfig separately, so
 * this does not disturb it: a first-time reader still lands on the theme their
 * OS asked for. Before that first click the button shows the system glyph
 * (chosen in upstream CSS off data-theme-choice, which we deliberately leave
 * alone) — accurate, since they are in fact on system.
 *
 * This is a wrap swizzle of a component Docusaurus considers unsafe; if a
 * major upgrade changes ColorModeToggle's props, revisit here.
 */
export default function ColorModeToggleWrapper(props: Props): ReactNode {
  const {colorMode} = useColorMode();
  return (
    <ColorModeToggle
      {...props}
      value={colorMode}
      respectPrefersColorScheme={false}
    />
  );
}
