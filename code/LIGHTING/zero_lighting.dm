
/atom/proc/SetLuminosity(var/v as num)
	src.luminosity = v
	return
/atom/proc/SetOpacity(var/v as num)
	src.opacity = v
	return

/turf/proc/GetLightLevel() 	// used by human/life.dm
	/*
	Unable to calculate actual value.
	Having 6 instead of 0 because otherwise scarysounds will occurs all the time and plantpeople never gets selfhealed.

	Can also do something like
	for(atom/A in view()) if (A.luminosity) return A.luminosity;
	but that will ruin the whole purpose of zero lighting system: to have zero CPU usage
	*/
	return 6

/area
	var/lighting_use_dynamic = 1

/area/New()
	..()
	master = src
	related = list(src)

	if(!requires_power)
		luminosity = 1
	else
		luminosity = 0
	return

/datum/controller/game_controller/setup_objects()
	world << "\red \b Initializing light and darkness..."
	world << "\red \b Using simple lighting!"
	return ..()


/mob/verb/faels_calibrating_explosion()
	set name = "FaELS calibrating explosion"
	set category = "Debug"
	var/turf/epicenter = locate(113, 128, 1) //AI
	var/start_time
	message_admins("\blue [ckey] creating an admin explosion at at ([epicenter.x],[epicenter.y],[epicenter.z]) \[[epicenter.loc]\].")
	sleep(0)
	start_time = world.timeofday
	explosion(epicenter, 3, 7, 14, 15)
	world << "\red \b FaELS calibrating explosion processed in [(world.timeofday-start_time)/10] seconds!"
	return
