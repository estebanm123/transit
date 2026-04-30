# Game design pillars
- You are transit minister with the goal of fixing the city's congestion before the next election. 
- Upon re-election, the expectations are higher (gameplay becomes difficult STS ascension style).
- Roguelike; runs are 1-2 hours
- Runs should be very different than the last - user should have many, regular choices in a variety gameplay .

## Budget
You are given a $ budget that replenishes by a set amount weekly.

## Abilities
Each week after your budget replenishes, you may enact gameplay modifiers known as abilities.

You may only choose from a limited set of abilities recommended by your advisors (selection initially random but could be influenced by other factors?).

?? After x weeks you may choose to hire a new advisor to acquire new abilities from a limited pool.

Abilities consume 3 resources
- Upfront cost
- Operating cost [optional]

Ability examples:
- 50K$ Marketing campaign (reduce car usage in area by very small amount)
- 20K$ Add bus stop (reduce bus speed + car usage)
- 500K$ Add a bus (reduce car usage in area)
- 100M$ Extend subway by 1KM
- 50M$ Build a new subway stop 
- ?$ Build bike lane (variants: painted vs protected [reduces car lane])
- ?$ Bus priority lane (car usage drops, but may increase car congestion)
- ?$ Add a car lane (car usage increases a bit?, congestion reduces in unrelated area, and is transferred to where car lane is added)
- ?$ Build a car tunnel 1KM
- ?$ Build a pedestrian overpass
- ?$ Build a pedestrian greenway
- ?$ Traffic light efficiency survey
- ?$ Congestion charge/toll
- ?$ (FUTURE: when rivers are implemented), build bridge

Bus/tram/subway/commuter abilities are known as 'transport' abilities. Their effects are based on where they're deployed to (ie. where the stations are) and the transit needs of the population residing in that area. Adding a new vehicle or station will lead to more of the population using that transport mode (instead of car or an alternative transport) if it shortens their commute.
FUTURE: maybe create a simplified heatmap view to help users analyze ideal line placements.

Transport lines are dynamically generated when you add your first bus/tram/subway/commuter stop or vehicle. When adding your next line or vehicle you have the option of creating a new line or adding the station/vehicle to an existing line.

TODO: Expand bus station car-reduction effects so they are based on bus frequency, not just station distance.

Commute demand is represented per residential land-use tile. Each low, medium, and
high-density residential tile generates a population, commute cost by mode, and
transport mode split for trips originating from that tile. City-wide transport
mode share is population-weighted across those tiles.

## Policies
These are permanent gameplay modifiers you collect (or may lose in events).

Every 8 weeks, the player can choose from certain policies to enact. Policies may also be enacted via events.

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
