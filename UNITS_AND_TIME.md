# Units and time — Step 12

Completed October 19, 2026. GameUnits provides explicit dimensional conversions,
bounded integer money helpers and explicit final rounding. VoyageDistance fixes
one canonical measurement for navigation and the payout fixture. No route finder,
ship controller, authoritative payout formula or world clock is implemented here.

## Conventions

| Dimension | Units and convention |
| --- | --- |
| Local length | 1 Godot world unit = 1 meter; millimeters are the bounded integer measurement representation |
| Navigation distance | 1 international nautical mile = 1852 meters |
| Speed | 1 knot = 1852/3600 meters per second |
| Time | seconds, milliseconds, minutes, hours; 60 seconds/minute, 3600 seconds/hour |
| Money | 100 integer minor credits per credit; decimal input parsed from text, never float |
| Mass | grams, kilograms, metric tonnes (1 tonne = 1,000,000 grams) |
| Volume | milliliters, liters, cubic meters (1 m3 = 1,000,000 ml) |
| Petroleum barrel | 42 US gallons; 158.987294928 liters, derived from 231 cubic inches/gallon and 0.0254 meters/inch |
| Container count | whole inventory objects; not container slots or TEU |
| Container slots | whole attachment/capacity positions; no automatic cargo count conversion |
| Hold count | whole physical holds; not cargo mass/volume/capacity |
| Heavy-item count | whole individual payloads; mass/dimensions are separate |
| DWT | a deadweight capacity rating in metric tonnes, not current cargo mass |

Bulk cargo mass uses grams, liquids/gas transport volume uses milliliters where
applicable, and containers/heavy payloads use counts plus their own physical data.
Cargo fuel and propulsion fuel share volume units but remain distinct inventory
and fuel fields. Gas pressure/reference conditions and density-based mass/volume
conversion must be explicitly defined when those families are implemented.
Current draft record schema still supports only its existing test cargo, not a
complete runtime cargo-family catalog. No hold/DWT/capacity values are approved.

Conversions reject unknown units, cross-dimension requests, negative/nonfinite
amounts, fractional counts/slots and results over 9e12. A barrel is specifically
a petroleum barrel; arbitrary "barrel" and ambiguous "ton" are unsupported names.
Direction/sign belongs to a velocity/controller, not these nonnegative quantities.

Primary conversion references:
- [NOAA Coast Pilot measurements](https://www.nauticalcharts.noaa.gov/publications/coast-pilot/files/cp4/CPB4_WEB.pdf)
- [NIST conversion tables](https://www.nist.gov/document/fs376-bpdf)

## Scaling and canonical voyage distance

Prototype defaults: navigation meters per world meter = 1; game seconds per real
second = 1. These do not select final Earth-map compression, time acceleration or
physical sphere radius. Geographic angular separation cannot become a meter
route without a separately chosen/validated distance service and scale.

VoyageDistance.configure receives an already measured world-meter route and an
explicit positive navigation scale. It applies the scale once, rounds once to
nearest millimeter (ties up), and cannot be reconfigured. Navigation reads NM
from that canonical amount. The payout test uses the same integer millimeters,
not rounded UI NM or a second measurement. Example: 1852 world meters at scale 2
is 2 NM for both consumers; a fixture rate of 125 minor credits/NM yields 250.

The payout fixture floors once to whole minor credits. Half an NM at 101 minor
credits/NM gives 50. This proves unit agreement, not an approved reward rate,
route eligibility, loaded distance or settlement rule. Multiplication is checked
before it happens: the intermediate must fit the 9e12 supported bound. Large
otherwise representable quotes may therefore be rejected; never wrap or clamp.
Consumers must use this boundary once navigation and payout exist.

## Rounding, currency and time

Money parse accepts nonnegative decimal text with at most two fractional digits;
12.30 is exactly 1230 minor credits. It rejects 1.005 instead of guessing a rounding
policy. Format uses integer division/remainder. Addition checks bounds before
adding. Refunds/debt use separately validated nonnegative fields, not negative
amounts accepted by the helper. No implicit money conversion goes through float.

Physical display conversions return float values. Quantization requires the
caller to select floor, ceil or nearest explicitly; nearest ties round up for
these nonnegative quantities. For the measured route the selected policy is
nearest millimeter; for the payout fixture it is floor at the end. Do not round
each segment/frame or repeatedly convert inventory units. Fractional transfer,
refinery yield and pricing policies remain the owning feature's decisions.

scaled_seconds takes a finite positive scale explicitly. It does not read system
UTC, advance a world clock or implement offline catch-up. Preserve fractional
elapsed time between ticks; Step 14 must own accumulator/clock policy, so repeatedly
truncating frame delta into milliseconds is not introduced by this step.

## Verification and limits

50 checks pass in the pinned engine and Windows Release: known conversions,
round trips, incompatible dimensions, counts, nonfinite inputs, rounding,
precise money text/bounds, overflow rejection, explicit time scaling and shared
navigation/payout distance. Normal native release startup passes. A script name
collision with Godot's built-in convert was fixed during validation; checks now
also have a 30-second owned-process timeout instead of hanging on script failure.

```powershell
./tools/Godot.ps1 -Mode UnitsCheck
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -UnitsProbe
```

No manual playtest is needed. These are math fixtures, not a working voyage,
economy, timer simulation or complete unit-aware save adapter.
