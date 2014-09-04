#if defined _explosivecars_included_
	#endinput
#endif
#define _explosivecars_included_

#define EXPLOSIVECARS_API_VERSON 1

 /**
 * Forwards when a car explodes
 *
 * @param attacker		Entity index of who triggers the explosion
 * @param car			Entity index of the exploded car
 */
 forward OnCarExploded(attacker, car);