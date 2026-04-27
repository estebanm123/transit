# Game design pillars
- You are transit minister with the goal of fixing the city's congestion before the next election. 
- Upon re-election, the expectations are higher (gameplay becomes difficult STS ascension style).
- Roguelike; runs are 1-2 hours
- Runs should be very different than the last - user should have many, regular choices in a variety gameplay .

## Budget
You are given a $ budget that replenishes by a set amount weekly.

## Abilities
Each week after your budget replenishes, you may enact gameplay modifiers known as abilities.

Abilities consume 3 resources
- Upfront cost
- Operating cost? TODO figure out how to do without overcomplicating
	- Consider this to be a type of ability in of itself? eg. bus/tram/subway/commuter maintance 
- Implementation duration in weeks.

Examples:
- 50K$ Marketing campaign (reduce car usage in area by very small amount)
- 20K$ Add bus stop (reduce bus speed and car usage in area)
- 500K$ Add a bus (reduce car usage in area)
- 100M$ Extend subway by 1KM
- 50M$ Build a new subway stop 
- ?$ Build bike lane (variants: painted vs protected [reduces car lane])
- ?$ Bus priority lane (car usage drops, but may increase car congestion)
- ?$ Add a car lane (car usage increases a bit?, congestion reduces in unrelated area, and is transferred to where car lane is added)
- ?$ Build a car tunnel
- ?$ Traffic light efficiency survey
- ?$ Congestion charge/toll
- ?$ TODO: when rivers are implemented, build bridge

Bus/tram/subway/commuter abilities are known as 'transport' abilities. Their effects are based on where they're deployed to (ie. where the stations are). TODO: maybe create a simplified heatmap view to help users analyze ideal line placements.

Transport lines are dynamically generated when you add your first bus/tram/subway/commuter stop or vehicle. When adding your next line or vehicle you have the option of creating a new line or adding the station/vehicle to an existing line.

TODO: how to restrict access to the gameplay modifiers? Having them all available at once may be overwhelming for the user and impede run variety. How could player acquire them over the course of their run?

## Policies
These are permanent gameplay modifiers you collect (or may lose in events).

- Fuel tax
- Congestion charge
- Extra subsidy
- Night Shift Economy - spread traffic needs across the day
- Work from home act - reduce traffic needs

## Events
Gameplay modifiers that have a set duration (some durations aren't shown to user eg. war, strike).

Users should have options to respond to events with different tradeoffs.

Consider some events as 'bosses' over a period that can be anticipated (eg. Strike, Olympics, Blizzard).

- Weather (smog, rain, snow)
- Accidents
- War
- Trade disputes (import inflation)
- Recession
- Strike
- Pothole
- Concert/Sports game/Festival/Olympics
- VIP motorcade
- Immigration boom
- New construction (high-res/commercial/industry/etc.)
- Factory closure
- Vehicle electrification
- Car free day
- Protests
- Anti-transit federal government party wins (or transit-friendly party wins)
	- This could maybe be influenced by some abilities (eg. lobbying/donations/bribes)

## Neighborhoods
Dynamically generated and can influence land use and commutting patterns.