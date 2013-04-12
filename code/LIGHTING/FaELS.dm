/*
   Welñome to FaELS
   Fast and Extended Lighting System
   v0.1
   by Rastaf0

   Features:
   * lesser lag during startup
   * minimal lag during playtime
   * supports more than 100% light (using semitransparent white overlay)
   * colored light
   * luminosity up to 36 cells

   Planned features:
   * 3D (for multifloor stations)
   * directed light
   * smooth transitions
   * no glithes lol
   * supports the Sun (shame to you, errorage and mport!)
   * supports other insanely lumenous entities


   The FaELS was inspired by sd_DynamicAreaLighting made by Shadowdarke.

*/


/*
   = Basics =
   Each atom has:
     luminosity  - a built-it BYOND var, affects how far mobs can see the atom.
     faels_luminosity - how much light emits the atom. For most atoms faels_luminousity is zero.
     opacity - a built-it BYOND var with obvious meanings.

   Brightness of light sources (var/atom/luminosity) is measured in Squares.
   N Squares produces 5 lux of illuminance at distance N turfs.
   Examples of illuminance (http://en.wikipedia.org/wiki/Lux)
     Illuminance         Surfaces illuminated by:
     10E-4 lux           Moonless, overcast night sky (starlight)
     0.002 lux           Moonless clear night sky with airglow
     0.27-1.0 lux        Full moon on a clear night
     3.4 lux             Dark limit of civil twilight under a clear sky
     50 lux              Family living room lights (Australia, 1998)
     80 lux              Office building hallway/toilet lighting
     100 lux             Very dark overcast day
     320-500 lux         Office lighting
     400 lux             Sunrise or sunset on a clear day.
     1,000 lux           Overcast day; typical TV studio lighting
     10,000-25,000 lux   Full daylight (not direct sun)
     32,000-130,000 lux  Direct sunlight

   As with sd_DynamicAreaLighting you have to call special procs when opacity or luminousity changes.
   For the compatiblity raisins these procs are called SetLuminosity, SetOpacity and so on.
   However, 100% compatibility cannot be acheived. Because the sd_DynamicAreaLighting suxx, bwahahaha!
   Just joking, it is awesome. But it is not enough awesome to work well with SS13.

   Note for coders:
     You may wonder why I am so freely redefining procedures like New() or Move().
     Would it cause problems? No, it wouldn't, because according BYOND's rules I am
     not REdefining or OVERwriting, I am ALSOdefining.
     See the code:

     smth/New()
     	world << "BEEP"
     	return ..()
     smth/New()
     	world << "BOOP"
     	return ..()

     it will print both "BEEP" and "BOOP". However the order is undefined so you can also get "BOOP BEEP".
     Of cource if you forgot to call "..()" you broke thing.


   = How the default BYOND lighting and visiblity system works =
   0. The blinded mob can see nothing.
   1. The mobs cannot see throught opaque obstracles (things with [opacity]=true)
   2. The mob always can see [see_in_dark] tiles around
      0 means it cannot see anything
      1 means it can see the tile (and stuff) under feets
      2 means a square 3x3 is visible and so on
   3. The lumenous objects themselves can be seen from any distance.
   4. The BYOND tries to support some sort of reflections which means
      turf can be lit even if a lightsource lies behind the corner of wall.
      This makes some sence in towns and caves, but we are IN SPESS and
      space does not reflect anything so BYOND's behavior will make strange effects.
      Deal with it.
      Anyway, how this shit works: see figure 1.

                 '
      ---------------------            "-" and "|" - Walls
        |233|*654321                   "*" - atom with luminosity = 7
        |2|4|6|54321     XY            number - some virtual variable called "litness"
        11|455|44321                   spaces represents completely dark areas.
      ---------------------            "M" - mob with M.client.view = 7
                 '                     "X" and "Y" - two possible positions of mob M (see figure 2 and 3)
                 '                     "'" - left border of screen as it seems for player of mob M.
                 '
                 '
         (figure 1)


      '
      '--                   The mob can see six rightmost lit tiles from here.
      '21    +++
      '21    +X+
      '21    +++
      '--
      '
      '
         (figure 2)


      '
      '                     However, when mob steps one tile right the BYOND will do strange thing:
      '       +++           the three tiles with litness 2 will of cource move out of the screen,
      '       +Y+           but the three tiles with litness 1 suddenly will become completely invisible.
      '       +++
      '
      '
      '
         (figure 3)


   5. The infralumenous object makes lit one tile underneath for
      mobs with [see_infrared]==true within [infra_luminosity] tiles range.
      BUG: the BYOND's documentatin sais only the infra lumenous object will be visible without
      tile and contents of tile. Just infrared object on the dark background.
      My tests prove documentation is wrong.
   6. The mob can NEVER see any objects with [invisibility] greater than mob's [see_invisible].
      However any affects caused by said object (i.e. luminosity, infra_luminosity, opacity) still be visible as usual.
      Yes, it is: we can even have invisible opaque objects.
*/

/* = PERFORMANCE and MEMORY USAGE =

                    total memory | startup lag | boot time | explosion_calibrated
	zero_lighting | 139 MB       |   0 s       | 60 s      | 18.2; 19.5; 16.8; 17.4; 16.2; avg 17.1
	sd_DAL        | 140 MB       |  30 s       | 75 s      | 18.4; 16.1; 17.5; 17.1; 18.7; avg 17.6
	FaELS (Debug) | 163 MB       |  17 s       | 87 s      | 18.8; 17.9; 18.8; 19.1; 19.0; avg 18.7
	FaELS         | 145 MB       |  4.5 s      | 69 s      | 19.8; 18.8; 19.9; 20.1; 19.5; avg 19.6
	FaELS         | 143 MB       |  18.8 s     | 90 s      | 14.3; 20.0; 18.0; 20.8;       avg 18.3
	FaELS         | 153 MB       |  11,1 s     | 86 s      | 19,0; 19.0; 19.2;             avg 19.1

  Total memory was measured after spawning of player.
  Startup lag is time which subsystem adds to lag in lobby.
    sd_DAL lags silently due to massive work in /turf/New().
  Boot time is time between pressing a button "GO" in DD and
    spawning player's character while links "ready" and "start now"
    were used as soon as possible.
  explosion_calibrated means the freeze after a large bomb being
    exploded in AI chamber. See faels_calibrating_explosion().
    Most of explosion time is FEA and some /obj/structure/ * /Del()

*/


/* ============ COMPATIBILITY LAYER ============*/

/atom/proc/SetOpacity(var/v as num)
	if (istype(FaELS))
		FaELS.set_opacity(src, v)
	else
		src.opacity = v
	return

/area
	var/lighting_use_dynamic = 1 // "0" means lighting effects shouldn't be applied in this area

/atom/proc/SetLuminosity(var/v as num)
	if (istype(FaELS))
		FaELS.set_luminosity(src, v)
	else
		src.luminosity = v
		//src.faels_pending_opacity = v
	//world << "DEBUG: FaELS: [src] /atom/proc/SetLuminosity/([v])"
	return


/turf/proc/GetLightLevel() 	// used by human/life.dm
	return faels_litness

/* ============ END OF COMPATIBLITY LAYER ============*/


/* ============ FaELS SETTINGS ============*/

#define FaELS_DEBUG //comment out to make release

#define FaELS_NUMBERS_FILE 'icons/misc/digits.dmi'  /* an icon must have states named "0", "1", "2" and so on */
#define FaELS_NOTHING_FILE 'icons/effects/effects.dmi'  /* an icon must have states named "0", "1", "2" and so on */
#define FaELS_DELAY 0 //delay before lighting changes will be visible. Events caused by movement are always instant.
#define FaELS_COLOR

#ifdef FaELS_COLOR
	#define FaELS_HUE_LIMIT 0x600 //hue value is always less than it
#endif

/* 0                                               - 100% black
 * 1 ... FaELS_DARK_SHADES                         - shades
 * FaELS_DARK_SHADES+1 ... FaELS_SHINE_TRESHOLD    - 100% transparent unless colored
 * FaELS_SHINE_TRESHOLD+1 ... FaELS_MAX_LUMINOSITY - semitransparent white
 */

#define FaELS_DARK_SHADES 6
#define FaELS_SHINE_TRESHOLD 25  // when things are too bright to look at
#define FaELS_LIGHT_SHINES 6
#define FaELS_MAX_LUMINOSITY 36

#ifndef FaELS_DEBUG ///in debug mode those constants are variables, see somewhere below
	#ifdef FaELS_COLOR
		#define FaELS_HUE_ROUNDING 64 //less means smoother image and more icons in memory
	#endif
	#define FaELS_LOGBASE 2.7 //how litness is combined. Eiler's number appears to be the best value here. TODO: get rid out of this constant.
#else
	#ifdef FaELS_COLOR
/*    */var/FaELS_HUE_ROUNDING = 64
	#endif
/**/var/FaELS_LOGBASE = 2.7
	#define FaELS_SMALL_MAP 0 //"1" makes debug messages be much more verbose
#endif


/* ============ END OF FaELS SETTINGS ============*/

/* ============ FaELS INTERNALS ============*/

#define FaELS_SHEDULED_TURF   (1<<0)
#define FaELS_SHEDULED_LIGHT  (1<<1)
#define FaELS_OP_SET_LUM      (1<<2)
#define FaELS_OP_OPACITY_SET  (1<<3)
#define FaELS_OP_OPACITY_CLR  (1<<4)

#ifdef FaELS_DEBUG
	#define FaELS_ASSERT(x) ASSERT(x)
#else
	#define FaELS_ASSERT(x)
#endif

#define FaELS_LX2METERS(N) round(log(FaELS_LOGBASE, N), 1)
#define FaELS_METERS2LX(N) round(FaELS_LOGBASE**N, 1)
/* ================= DEFINITIONS ================== */

/datum/FaELS
	//var/obj/effect/overlay/test
	//var/image/test2
	var/list/icon/icons = new
	var/update_is_sheduled = 0
	var/force_delay_updates = 1 //for startup and explosions. Makes ALL requests to be queued, do_update() must be called directly.
	var/list/lights_to_update = new
	var/list/turfs_to_update = new
	var/list/turf_data_storage = new
	//var/iteration = 0

	#ifdef FaELS_DEBUG
	var/list/icon/numbers = new
	var/show_numbers = 0
	#endif



/atom
	// those three variables can be packed into one using bitmagik but I do not want it.
	var/faels_luminosity // current luminosity
	var/faels_pending_luminosity // luminosity to be set after next update
	var/faels_flags = 0
	#ifdef FaELS_COLOR
/*
 Hue ranges from 0 to 0x5ff (1535)

		0x000 = red
		0x100 = yellow
		0x200 = green
		0x300 = cyan
		0x400 = blue
		0x500 = magenta

		null = white
*/
	var/faels_hue
	#endif

/turf
	var/list/faels_lights
	var/faels_litness
	#ifdef FaELS_DEBUG
	var/icon/faels_overlay_debug
	#endif

/datum/faels_turf_data
	var/list/faels_lights
	var/opacity

/* ================= END OF DEFINITIONS ================== */

/* ================= CORE ================== */

var/datum/FaELS/FaELS = new // CREATING GLOBAL OBJECT

/datum/controller/game_controller/setup_objects()
	world << "\red \b Initializing light and darkness..."
	FaELS.initialize()
	return ..()

/datum/FaELS/New()
/*
	test = new /obj/effect/overlay(  )
	test.icon = 'ss13_dark_alpha7.dmi'
	test.icon_state = "0to6"
	test.layer = FaELS_LAYER
	test.mouse_opacity = 0
*/
/*
Can make pregenerating icons here but it wouldn't be much better than existing ondemand generating.
Transferring icons in mid-round is not good and causes some minor glithes.
TODO: make dmi file with all stages - that may help alot with traffic.
*/
	#ifdef FaELS_DEBUG
	var/list/icon/digits = new
	for (var/i=0,i<10,i++)
		digits += icon(FaELS_NUMBERS_FILE,icon_state=num2text(i))

	for (var/ix=0,ix<10,ix++)
		for (var/xj=0,xj<10,xj++)
			if (ix==0)
				numbers += digits[xj+1]
			else
				var/icon/I = icon(FaELS_NOTHING_FILE, "nothing")
				I.Blend(digits[ix+1],ICON_OVERLAY, -6)
				I.Blend(digits[xj+1],ICON_OVERLAY, 6)
				numbers += I
	#endif
	return

/datum/FaELS/proc/initialize()
	set background = 0 //zero!
	force_delay_updates = 1
	//#ifdef FaELS_DEBUG
	var/start_time
	start_time = world.timeofday
	//#endif
/*
	for(var/zlevel=1,zlevel<=world.maxz,zlevel++)
		for(var/turf/T in block(locate(1,1,zlevel),locate(world.maxx,world.maxy,zlevel)))
			if (!istype(T, /turf/space))
				turfs_to_update += T
				T.faels_flags = FaELS_SHEDULED_TURF
*/
	for(var/turf/T)
		if (!istype(T, /turf/space))
			turfs_to_update += T
			T.faels_flags = FaELS_SHEDULED_TURF
	for (var/atom/A)
		if (isarea(A))
			continue
		if (A.luminosity)
			set_luminosity(A, A.luminosity)
	//for (var/turf/space/T)
	//	set_luminosity(T, 2)

	var/ltu = lights_to_update.len
	var/ttu = turfs_to_update.len
	do_update()
	force_delay_updates = 0
	world << "\red \b Using FaELS. [ltu] lights and [ttu] turfs processed in [(world.timeofday-start_time)/10] seconds!"
	return 1


/*
 * Shedules all graphic-related actions to be applied as soon as possible
 * Made as a pair of proc and macros for maximum performance.
 * Maybe it will be better to make everithing in macro, but I am afraid
 * the "spawn" will copy local variables owned by proc who contains the macro despite they aren't used.
 */
/datum/FaELS/proc/shedule_update()
	FaELS_ASSERT(update_is_sheduled==FALSE)
	update_is_sheduled = 1
	spawn (FaELS_DELAY)
		do_update()
	return 1

#define FaELS_UPDATE if(!force_delay_updates&&!update_is_sheduled){shedule_update();}
//#define FaELS_UPDATE if(!force_delay_updates&&!update_is_sheduled){update_is_sheduled = 1;spawn(FaELS_DELAY){do_update();}}

/*
 * Applies all pending graphic-related actions
 */
/datum/FaELS/proc/do_update()
	#ifdef FaELS_DEBUG
	world << "DEBUG: FaELS: /datum/FaELS/proc/do_update() lights_to_update.len=[lights_to_update.len], turfs_to_update.len=[turfs_to_update.len]"
	#endif
	#ifdef FaELS_DEBUG
	var/op_setlum = 0
	var/op_setgraph = 0
	#endif

	for (var/atom/I in lights_to_update)
		if (!(I.faels_flags & FaELS_SHEDULED_LIGHT))
			continue
		var/flags = I.faels_flags & (FaELS_OP_SET_LUM|FaELS_OP_OPACITY_SET|FaELS_OP_OPACITY_CLR)

		if      (flags == FaELS_OP_SET_LUM && I.faels_luminosity == 0 && (isnull(I.faels_pending_luminosity) || I.faels_pending_luminosity == 0))
			//do nothing
			#ifdef FaELS_DEBUG
			var/turf/center = get_turf(I)
			world << "DEBUG: FaELS: do_update: doing nothing with [I] at [coords2text(center)] \[[center.loc]\]"
			#endif
			I.faels_pending_luminosity = null
		else if (flags & FaELS_OP_SET_LUM && I.faels_luminosity == 0 && I.faels_pending_luminosity >  0)
			 //lamp has been turned on
			I.luminosity = I.faels_pending_luminosity
			I.faels_luminosity = I.faels_pending_luminosity
			make_light(I, I.faels_pending_luminosity )
			I.faels_pending_luminosity = null
		else if (flags & FaELS_OP_SET_LUM && I.faels_luminosity > 0  && I.faels_pending_luminosity == 0)
			//lamp has been turned off
			I.luminosity = 0
			turnoff_light(I, I.faels_luminosity )
			I.faels_luminosity = 0
			I.faels_pending_luminosity = null
		else if (flags == FaELS_OP_OPACITY_SET)
			//obstacles have occured (door has been closed, wall constructed, etc)
			handle_opacity_set(I)
		else if (flags == FaELS_OP_OPACITY_CLR)
			//obstacles have vanished (door has been opened, bomb exploded, etc)
			handle_opacity_clear(I)
		else if (flags == (FaELS_OP_OPACITY_SET|FaELS_OP_OPACITY_CLR))
			//obstacles have both occured and vanished (or just moved)
			update_light(I, I.faels_luminosity, I.faels_luminosity)
		else //luminosity has been changed a bit
			I.luminosity = I.faels_pending_luminosity
			update_light(I, I.faels_pending_luminosity, I.faels_luminosity)
			I.faels_luminosity = I.faels_pending_luminosity
			I.faels_pending_luminosity = null
		I.faels_flags &= ~(FaELS_SHEDULED_LIGHT|FaELS_OP_SET_LUM|FaELS_OP_OPACITY_SET|FaELS_OP_OPACITY_CLR)

		#ifdef FaELS_DEBUG
		op_setlum++
		#endif
	update_is_sheduled = 0
	lights_to_update.len = 0

	for (var/turf/T in turfs_to_update)
		if (!(T.faels_flags & FaELS_SHEDULED_TURF))
			continue
		#ifdef FaELS_DEBUG
		op_setgraph++
		#endif
		T.faels_apply_overlay()
		T.faels_flags &= ~FaELS_SHEDULED_TURF
	turfs_to_update.len = 0

	#ifdef FaELS_DEBUG
	world << "DEBUG: FaELS: [op_setlum] lights, [op_setgraph] turfs."
	#endif
	return 1

/datum/FaELS/proc/set_luminosity(var/atom/A, var/new_luminosity as num)
	new_luminosity = min(new_luminosity, FaELS_MAX_LUMINOSITY)
	if (!(A.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
		if (A.faels_luminosity == new_luminosity) //nothing to do
			return
		lights_to_update += A
		A.faels_flags |= FaELS_SHEDULED_LIGHT|FaELS_OP_SET_LUM
		FaELS_UPDATE
	else
		if (A.faels_pending_luminosity == new_luminosity) //nothing to do
			return
		A.faels_flags |= FaELS_OP_SET_LUM
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		var/turf/center = get_turf(A)
		world << "DEBUG: FaELS: FaELS/set_luminosity([A] at [coords2text(center)] \[[center.loc]\], [new_luminosity]); faels_luminosity=[A.faels_luminosity], faels_pending_luminosity=[A.faels_pending_luminosity]"
	#endif
	A.faels_pending_luminosity = new_luminosity
	return

/datum/FaELS/proc/set_opacity(var/atom/A, var/new_opacity as num)
	if (A.opacity == new_opacity)
		return
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		var/turf/center = get_turf(A)
		world << "DEBUG: FaELS: FaELS/set_opacity([A] at [coords2text(center)] \[[center.loc]\], [new_opacity]); old_opacity=[A.opacity]"
	#endif
	A.opacity = new_opacity
	var/turf/T = FaELS_get_turf(A)
	if(T && T.faels_lights && T.faels_lights.len)
		if (!(T.faels_flags & FaELS_SHEDULED_TURF))
			T.faels_flags |= FaELS_SHEDULED_TURF
			turfs_to_update += T
		for (var/atom/L in T.faels_lights)
			if (!(L.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
				L.faels_flags |= FaELS_SHEDULED_LIGHT|(A.opacity?FaELS_OP_OPACITY_SET:FaELS_OP_OPACITY_CLR)
				lights_to_update += L
			else
				L.faels_flags |= A.opacity?FaELS_OP_OPACITY_SET:FaELS_OP_OPACITY_CLR
		FaELS_UPDATE
	return

/datum/FaELS/proc/on_Del(atom/A)
	var/turf/T = FaELS_get_turf(A)
	if (!T)
		return
	#ifdef FaELS_DEBUG
	var/needs_to_trace = 0
	#endif
	if (A.faels_luminosity)
		delete_light(T, A.faels_luminosity)
		FaELS_UPDATE
		#ifdef FaELS_DEBUG
		needs_to_trace = 1
		#endif
	if (A.opacity)
		if(T.faels_lights && T.faels_lights.len)
			for (var/atom/L in T.faels_lights)
				if (!(L.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
					L.faels_flags |= FaELS_SHEDULED_LIGHT|FaELS_OP_OPACITY_CLR
					lights_to_update += L
				else
					L.faels_flags |= FaELS_OP_OPACITY_CLR
			FaELS_UPDATE
			#ifdef FaELS_DEBUG
			needs_to_trace = 1
			#endif

	#ifdef FaELS_DEBUG
	if (needs_to_trace && (FaELS_SMALL_MAP || !force_delay_updates))
		world << "DEBUG: FaELS: on_Del([A] at [coords2text(T)] \[[T.loc]\]); opacity=[A.opacity],  faels_luminosity=[A.faels_luminosity]"
	#endif
	return


/datum/FaELS/proc/on_Move(var/atom/movable/A, var/turf/old_T)
	var/turf/T = FaELS_get_turf(A)
	if (A.faels_luminosity)
		if      (T==old_T) //can happen when a person gets a flashlight from backpack to hands while sitting in a locker
			//do nothing
		else if (!old_T && T) //from nowhere to world
			if (!(A.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
				A.faels_flags |= FaELS_SHEDULED_LIGHT|FaELS_OP_OPACITY_CLR
				lights_to_update += A
			else
				A.faels_flags |= FaELS_OP_SET_LUM
			FaELS_UPDATE
		else if (old_T && !T) //disappears/hides
			strip_light(old_T, A, A.faels_luminosity)
			FaELS_UPDATE

		else //moves
			update_light(A, A.faels_luminosity, A.faels_luminosity, old_T)
			FaELS_UPDATE
	if (A.opacity)
		if      (T==old_T) //can happen when a person gets a flashlight from backpack to hands while sitting in a locker
			//do nothing
		else
			if (T) //from nowhere to world
				if(T.faels_lights && T.faels_lights.len)
					for (var/atom/L in T.faels_lights)
						if (!(L.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
							L.faels_flags |= FaELS_SHEDULED_LIGHT|FaELS_OP_OPACITY_SET
							lights_to_update += L
						else
							L.faels_flags |= FaELS_OP_OPACITY_SET
					FaELS_UPDATE
			if (old_T) //disappears/hides
				if(old_T.faels_lights && old_T.faels_lights.len)
					for (var/atom/L in old_T.faels_lights)
						if (!(L.faels_flags & FaELS_SHEDULED_LIGHT)) // if NOT sheduled
							L.faels_flags |= FaELS_SHEDULED_LIGHT|FaELS_OP_OPACITY_CLR
							lights_to_update += L
						else
							L.faels_flags |= FaELS_OP_OPACITY_CLR
					FaELS_UPDATE
	#ifdef FaELS_DEBUG
	if ((FaELS_SMALL_MAP || !force_delay_updates))
		var/text_from = isturf(old_T) ? "[coords2text(old_T)] \[[old_T.loc]\]" : "[old_T]"
		var/text_to = isturf(T) ? "[coords2text(T)] \[[T.loc]\]" : "[T]"
		world << "DEBUG: FaELS: on_Move([A] moved from [text_from] to [text_to]); opacity=[A.opacity],  faels_luminosity=[A.faels_luminosity]"
	#endif
	return


/datum/FaELS/proc/on_New_turf(turf/T)
	T.faels_flags |= FaELS_SHEDULED_TURF
	turfs_to_update += T
	FaELS_UPDATE
	var/dataid = "[T.x],[T.y],[T.z]"
	var/datum/faels_turf_data/d = FaELS.turf_data_storage[dataid]
	if (d)
		FaELS.turf_data_storage -= dataid
		T.faels_lights = d.faels_lights
		if (T.opacity != d.opacity)
			T.opacity = d.opacity
			FaELS.set_opacity(T, !d.opacity)
	else
		if (T.opacity)
			T.opacity = 0
			FaELS.set_opacity(T, 1)
	if (T.luminosity)
		FaELS.set_luminosity(T, T.luminosity)

	#ifdef FaELS_DEBUG
	if ((FaELS_SMALL_MAP || !force_delay_updates))
		world << "DEBUG: FaELS: on_New_turf([T] at [coords2text(T)] \[[T.loc]\]); opacity=[T.opacity],  faels_luminosity=[T.faels_luminosity]"
	#endif
	return


/datum/FaELS/proc/on_New_area(area/A)
	#ifdef FaELS_DEBUG
	var/turf/tmp_turf = locate() in A
	var/has_work_done = !isnull(tmp_turf)
	#endif
	for (var/turf/T in A)
		T.faels_flags |= FaELS_SHEDULED_TURF
		turfs_to_update += T
	FaELS_UPDATE
	#ifdef FaELS_DEBUG
	if (has_work_done)
		world << "DEBUG: FaELS: on_New_area([A])"
	#endif

/datum/FaELS/proc/on_New_movable(atom/movable/A)
	if (A.opacity)
		A.opacity = 0
		FaELS.set_opacity(A, 1)
	if (A.luminosity)
		FaELS.set_luminosity(A, A.luminosity)
	return

/datum/FaELS/proc/update_turfs(L) //L may be a list or an area
	for (var/turf/T in L)
		T.faels_flags |= FaELS_SHEDULED_TURF
		turfs_to_update += T
	FaELS_UPDATE
	return

/turf/New()
	if (istype(FaELS))
		FaELS.on_New_turf(src)
	return ..()

/turf/Del()
	if (istype(FaELS))
		var/datum/faels_turf_data/d = new
		d.faels_lights = faels_lights
		d.opacity = opacity
		FaELS.turf_data_storage["[x],[y],[z]"] = d
	return ..()

/atom/movable/New()
	if((luminosity || opacity) && istype(FaELS))
		FaELS.on_New_movable(src)
	return ..()

/atom/Del()
	if(/*!isarea(src) &&*/ (faels_luminosity || opacity) && istype(FaELS)) //areas never have faels_luminosity or opacity
		FaELS.on_Del(src)
	..()
	return

/atom/movable/Move() // when something moves
	if((faels_luminosity || opacity) && istype(FaELS))
		var/turf/old_turf = FaELS_get_turf(src)
		. = ..()
		if (.)
			FaELS.on_Move(src, old_turf)
	else
		. = ..()
	return


#define RANGE_TURFS(RADIUS, CENTER) \
	block( \
			locate(max(CENTER.x-(RADIUS),1),			max(CENTER.y-(RADIUS),1),			CENTER.z), \
			locate(min(CENTER.x+(RADIUS),world.maxx),	min(CENTER.y+(RADIUS),world.maxy),	CENTER.z) \
			)

#define HYPOTENUSE(Loc1, Loc2) (sqrt((Loc1.x - Loc2.x)**2 + (Loc1.y - Loc2.y)**2))
//TODO: HYPOTENUSE_SQR

/* MAIN UNIVERSAL FUNCTION */
/datum/FaELS/proc/update_light(var/atom/source, var/new_luminosity, var/old_luminosity, var/turf/old_center = null)
	var/turf/center = FaELS_get_turf(source)
	if (!center)
		return
	if (!old_center)
		old_center = center
	var/list/turf/new_view = view(new_luminosity-1, center)
	var/list/turf/old_range = RANGE_TURFS(old_luminosity-1, old_center)
	#ifdef FaELS_DEBUG
	var/old_range_old_len = old_range.len
	#endif
	old_range -= new_view //because of that important line I cannot use byond-accelerated code like "for(blah in view())".
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		var/new_view_len=0
		for (var/turf/T in new_view)
			new_view_len++
		if (center==old_center)
			world << "DEBUG: FaELS: update_light([source] at [coords2text(center)] \[[center.loc]\], [new_luminosity], [old_luminosity]): new_view=[new_view_len], old_range=[old_range_old_len] -> [old_range.len]"
		else
			world << "DEBUG: FaELS: update_light([source] at [coords2text(center)] \[[center.loc]\], [new_luminosity], [old_luminosity], [old_center] at [coords2text(old_center)] \[[old_center.loc]\]): new_view=[new_view_len], old_range=[old_range_old_len] -> [old_range.len]"
	#endif
	for (var/turf/T in old_range)
		if (round(HYPOTENUSE(old_center, T)) >= old_luminosity)
			continue
		if (!T.faels_lights)
			continue
		if (T.faels_lights.Remove(source))
			if (T.faels_lights.len==0)
				del(T.faels_lights)
			if (!(T.faels_flags & FaELS_SHEDULED_TURF))
				T.faels_flags |= FaELS_SHEDULED_TURF
				turfs_to_update += T

	for (var/turf/T in new_view)
		var/d = round(HYPOTENUSE(center, T))
		if (d < new_luminosity)
			if (!T.faels_lights)
				T.faels_lights = new
			T.faels_lights[source] = new_luminosity-d
			if (!(T.faels_flags & FaELS_SHEDULED_TURF))
				T.faels_flags |= FaELS_SHEDULED_TURF
				turfs_to_update += T
		else
			if (T.faels_lights && T.faels_lights.Remove(source))
				if (T.faels_lights.len==0)
					del(T.faels_lights)
				if (!(T.faels_flags & FaELS_SHEDULED_TURF))
					T.faels_flags |= FaELS_SHEDULED_TURF
					turfs_to_update += T

	return

/* FAST SPECIALIZED FUNCTION */
/datum/FaELS/proc/handle_opacity_set(var/atom/source)
	var/turf/center = FaELS_get_turf(source)
	if (!center)
		return

	var/list/turf/new_view = view(source.faels_luminosity-1, center)
	var/list/turf/old_range = RANGE_TURFS(source.faels_luminosity-1, center)
	#ifdef FaELS_DEBUG
	var/old_range_old_len = old_range.len
	#endif
	old_range-=new_view
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		world << "DEBUG: FaELS: handle_opacity_set([source] at [coords2text(center)] \[[center.loc]\]): source.faels_luminosity=[source.faels_luminosity], new_view=[new_view.len], old_range=[old_range_old_len] -> [old_range.len]"
	#endif
	for (var/turf/T in old_range)
		if (round(HYPOTENUSE(center, T)) >= source.faels_luminosity)
			continue
		if (!T.faels_lights)
			continue
		if (T.faels_lights.Remove(source))
			if (T.faels_lights.len==0)
				del(T.faels_lights)
			if (!(T.faels_flags & FaELS_SHEDULED_TURF))
				T.faels_flags |= FaELS_SHEDULED_TURF
				turfs_to_update += T
	return

/* FAST SPECIALIZED FUNCTION */
/datum/FaELS/proc/handle_opacity_clear(var/atom/source)
	var/turf/center = FaELS_get_turf(source)
	if (!center)
		return

	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		world << "DEBUG: FaELS: handle_opacity_clear([source] at [coords2text(center)] \[[center.loc]\]): source.faels_luminosity=[source.faels_luminosity]"
	#endif
	for (var/turf/T in view(source.faels_luminosity-1, center))
		var/d = round(HYPOTENUSE(center, T))
		if (d>=source.faels_luminosity)
			continue
		if (!T.faels_lights)
			T.faels_lights = new
		else if (source in T.faels_lights)
			continue
		T.faels_lights[source] = source.faels_luminosity-d
		if (!(T.faels_flags & FaELS_SHEDULED_TURF))
			T.faels_flags |= FaELS_SHEDULED_TURF
			turfs_to_update += T
	return


/* FAST SPECIALIZED FUNCTION */
/datum/FaELS/proc/make_light(var/atom/source, var/new_luminosity)
	var/turf/center = FaELS_get_turf(source)
	if (!center)
		return

	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		world << "DEBUG: FaELS: make_light([source] at [coords2text(center)] \[[center.loc]\], [new_luminosity])"
	#endif

	//var/tmp_lum = center.luminosity //save
	//center.luminosity = new_luminosity //for correct work of view() //already done by caller
	for (var/turf/T in view(new_luminosity-1, center))
		var/d = round(HYPOTENUSE(center, T))
		if (d>=new_luminosity)
			continue
		if (!T.faels_lights)
			T.faels_lights = new
		T.faels_lights[source] = new_luminosity-d
		if (!(T.faels_flags & FaELS_SHEDULED_TURF))
			T.faels_flags |= FaELS_SHEDULED_TURF
			turfs_to_update += T
	//center.luminosity = tmp_lum //restore
	return

/* FAST SPECIALIZED FUNCTION */
/datum/FaELS/proc/turnoff_light(var/atom/source, var/old_luminosity)
	var/turf/center = FaELS_get_turf(source)
	if (!center)
		return
	//#ifdef FaELS_DEBUG
	//if (FaELS_SMALL_MAP || !force_delay_updates)
	//	world << "DEBUG: FaELS: turnoff_light([source] at [coords2text(center)] \[[center.loc]\], [old_luminosity])"
	//#endif
	strip_light(center, source, old_luminosity)
	return

/* FAST SPECIALIZED FUNCTION */
/datum/FaELS/proc/strip_light(var/turf/center, var/atom/source, var/old_luminosity)
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		var/turf/cur_center = FaELS_get_turf(source)
		if (cur_center==center)
			world << "DEBUG: FaELS: strip_light([source] at [coords2text(center)] \[[center.loc]\], [old_luminosity])"
		else if (cur_center)
			world << "DEBUG: FaELS: strip_light([source] moved from [coords2text(center)] \[[center.loc]\] to [coords2text(cur_center)] \[[cur_center.loc]\], [old_luminosity])"
		else
			world << "DEBUG: FaELS: strip_light([source] disappeared from [coords2text(center)] \[[center.loc]\], [old_luminosity])"
	#endif
	for (var/turf/T in RANGE_TURFS(old_luminosity-1, center))
		var/d = round(HYPOTENUSE(center, T))
		if (d>=old_luminosity)
			continue
		if (!T.faels_lights)
			continue
		if (T.faels_lights.Remove(source))
			if (T.faels_lights.len==0)
				del(T.faels_lights)
			if (!(T.faels_flags & FaELS_SHEDULED_TURF))
				T.faels_flags |= FaELS_SHEDULED_TURF
				turfs_to_update += T
	return

/* SPECIALIZED FUNCTION For calling from Del() */
/datum/FaELS/proc/delete_light(var/turf/center, var/old_luminosity)
	#ifdef FaELS_DEBUG
	if (FaELS_SMALL_MAP || !force_delay_updates)
		world << "DEBUG: FaELS: delete_light(something at [coords2text(center)] \[[center.loc]\], [old_luminosity])"
	#endif
	for (var/turf/T in RANGE_TURFS(old_luminosity-1, center))
		var/d = round(HYPOTENUSE(center, T))
		if (d>=old_luminosity)
			continue
		if (!T.faels_lights)
			continue
		if (!(T.faels_flags & FaELS_SHEDULED_TURF))
			T.faels_flags |= FaELS_SHEDULED_TURF
			turfs_to_update += T // T.faels_lights will be cleared automatically once source gets deleted
	return

/* ================= END OF CORE ================== */


/* ================= VISUAL ================== */


/datum/FaELS/proc/get_icon(faels_color)
	var/icon/alphaoverlay = icons[faels_color]
	if (!alphaoverlay)
		alphaoverlay = icon(FaELS_NOTHING_FILE, "nothing")
		alphaoverlay.Blend(faels_color,ICON_OVERLAY)
		icons[faels_color] = alphaoverlay
	return alphaoverlay

/*
 * Areas are used as click-transparent overlays. There is no other way to do that.
 */
/area/New(loc, faels_color, area/faels_template_area, newtag)
	..()
	if (lighting_use_dynamic && faels_color)
		ASSERT(istype(FaELS))
		//faels_created = 1  //not needed

		// replicate vars
		for(var/V in faels_template_area.vars)
			if (V=="contents" || V=="overlays" || !issaved(faels_template_area.vars[V]))
				continue
			src.vars[V] = faels_template_area.vars[V]

		//select icon
		src.overlays += FaELS.get_icon(faels_color)
		//TODO: move plasma/n2o/fire overlays here

		//add area to pool
		related += src
		tag = newtag
	else
		if(!tag)
			tag = "[type]"
		master = src
		related = list(src)

	//There is an issue in byond: sometimes lit (but not lumenous) turfs are not shown for player.
	//Here's the workaround: set not completely dark turfs as lumenous.
	//Also, special areas are always lit magically.
	luminosity = (lighting_use_dynamic && faels_color != "#000000e0") || !requires_power
	return

/area/Del()
	related -= src
	..()
	return

#ifdef FaELS_DEBUG

/mob/verb/faels_set_logbase()
	set name = "FaELS set logbase"
	set category = "Debug"
	var/r = input(usr,"FaELS_LOGBASE=","FaELS",FaELS_LOGBASE) as num
	if (isnull(r) || r<=1)
		return
	FaELS_LOGBASE = r
	world << "\red \b FaELS logbase has been set to [FaELS_LOGBASE]"
	faels_reset()
	return

/mob/verb/faels_set_hue_rounding()
	set name = "FaELS set hue rounding"
	set category = "Debug"
	var/r = input(usr,"FaELS_HUE_ROUNDING=","FaELS",FaELS_HUE_ROUNDING) as num
	if (isnull(r) || r<1)
		return
	FaELS_HUE_ROUNDING = r
	world << "\red \b FaELS hue rounding has been set to [FaELS_HUE_ROUNDING]"
	faels_reset()
	return

#endif

#ifdef FaELS_COLOR

#ifdef FaELS_DEBUG

var/k_shade_v = 0
var/k_shade_v_a = 0
var/k_shade_v_l = 0
var/k_shade_v_la = 1

var/k_shade_a = 1
var/k_shade_a_a = 0
var/k_shade_a_l = -0.9
var/k_shade_a_la = 0.5

var/k_shine_s = 0
var/k_shine_s_a = 1
var/k_shine_s_l = 0
var/k_shine_s_la = 0

var/k_shine_a = 0.5
var/k_shine_a_a = 0
var/k_shine_a_l = 0.5
var/k_shine_a_la = 0.5

/mob/verb/faels_set_k_shade_v_filler()
	set name = "FaELS ____"
	set category = "Debug"
	return

/mob/verb/faels_set_k_shade_v()
	set name = "FaELS set k_shade_v"
	set category = "Debug"
	var/r = input(usr,"k_shade_v=","FaELS",k_shade_v) as num
	if (isnull(r))
		return
	k_shade_v = r
	world << "\red \b FaELS k_shade_v has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_v_a()
	set name = "FaELS set k_shade_v_a"
	set category = "Debug"
	var/r = input(usr,"k_shade_v_a=","FaELS",k_shade_v_a) as num
	if (isnull(r))
		return
	k_shade_v_a = r
	world << "\red \b FaELS k_shade_v_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_v_l()
	set name = "FaELS set k_shade_v_l"
	set category = "Debug"
	var/r = input(usr,"k_shade_v_l=","FaELS",k_shade_v_l) as num
	if (isnull(r))
		return
	k_shade_v_l = r
	world << "\red \b FaELS k_shade_v_l has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_v_la()
	set name = "FaELS set k_shade_v_la"
	set category = "Debug"
	var/r = input(usr,"k_shade_v_la=","FaELS",k_shade_v_la) as num
	if (isnull(r))
		return
	k_shade_v_la = r
	world << "\red \b FaELS k_shade_v_la has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_a()
	set name = "FaELS set k_shade_a"
	set category = "Debug"
	var/r = input(usr,"k_shade_a=","FaELS",k_shade_a) as num
	if (isnull(r))
		return
	k_shade_a = r
	world << "\red \b FaELS k_shade_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_a_a()
	set name = "FaELS set k_shade_a_a"
	set category = "Debug"
	var/r = input(usr,"k_shade_a_a=","FaELS",k_shade_a_a) as num
	if (isnull(r))
		return
	k_shade_a_a = r
	world << "\red \b FaELS k_shade_a_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_a_l()
	set name = "FaELS set k_shade_a_l"
	set category = "Debug"
	var/r = input(usr,"k_shade_a_l=","FaELS",k_shade_a_l) as num
	if (isnull(r))
		return
	k_shade_a_l = r
	world << "\red \b FaELS k_shade_a_l has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shade_a_la()
	set name = "FaELS set k_shade_a_la"
	set category = "Debug"
	var/r = input(usr,"k_shade_a_la=","FaELS",k_shade_a_la) as num
	if (isnull(r))
		return
	k_shade_a_la = r
	world << "\red \b FaELS k_shade_a_la has been set to [r]"
	faels_reset()
	return


/mob/verb/faels_set_k_shine_s()
	set name = "FaELS set k_shine_s"
	set category = "Debug"
	var/r = input(usr,"k_shine_s=","FaELS",k_shine_s) as num
	if (isnull(r))
		return
	k_shine_s = r
	world << "\red \b FaELS k_shine_s has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_s_a()
	set name = "FaELS set k_shine_s_a"
	set category = "Debug"
	var/r = input(usr,"k_shine_s_a=","FaELS",k_shine_s_a) as num
	if (isnull(r))
		return
	k_shine_s_a = r
	world << "\red \b FaELS k_shine_s_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_s_l()
	set name = "FaELS set k_shine_s_l"
	set category = "Debug"
	var/r = input(usr,"k_shine_s_l=","FaELS",k_shine_s_l) as num
	if (isnull(r))
		return
	k_shine_s_l = r
	world << "\red \b FaELS k_shine_s_l has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_s_la()
	set name = "FaELS set k_shine_s_la"
	set category = "Debug"
	var/r = input(usr,"k_shine_s_la=","FaELS",k_shine_s_la) as num
	if (isnull(r))
		return
	k_shine_s_la = r
	world << "\red \b FaELS k_shine_s_la has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_a()
	set name = "FaELS set k_shine_a"
	set category = "Debug"
	var/r = input(usr,"k_shine_a=","FaELS",k_shine_a) as num
	if (isnull(r))
		return
	k_shine_a = r
	world << "\red \b FaELS k_shine_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_a_a()
	set name = "FaELS set k_shine_a_a"
	set category = "Debug"
	var/r = input(usr,"k_shine_a_a=","FaELS",k_shine_a_a) as num
	if (isnull(r))
		return
	k_shine_a_a = r
	world << "\red \b FaELS k_shine_a_a has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_a_l()
	set name = "FaELS set k_shine_a_l"
	set category = "Debug"
	var/r = input(usr,"k_shine_a_l=","FaELS",k_shine_a_l) as num
	if (isnull(r))
		return
	k_shine_a_l = r
	world << "\red \b FaELS k_shine_a_l has been set to [r]"
	faels_reset()
	return

/mob/verb/faels_set_k_shine_a_la()
	set name = "FaELS set k_shine_a_la"
	set category = "Debug"
	var/r = input(usr,"k_shine_a_la=","FaELS",k_shine_a_la) as num
	if (isnull(r))
		return
	k_shine_a_la = r
	world << "\red \b FaELS k_shine_a_la has been set to [r]"
	faels_reset()
	return

#endif
/proc/faels_hsv2rgb(hue, sat, val, alpha)
// Borrowed from IconProcs made by Lummox JR

	// Compress hue into easier-to-manage range
	hue -= hue >> 8

	var/hi,mid,lo,r,g,b
	hi = val
	lo = round((255 - sat) * val / 255, 1)
	mid = lo + round(abs(round(hue, 510) - hue) * (hi - lo) / 255, 1)
	if(hue >= 765)
		if(hue >= 1275)      {r=hi;  g=lo;  b=mid}
		else if(hue >= 1020) {r=mid; g=lo;  b=hi }
		else                 {r=lo;  g=mid; b=hi }
	else
		if(hue >= 510)       {r=lo;  g=hi;  b=mid}
		else if(hue >= 255)  {r=mid; g=hi;  b=lo }
		else                 {r=hi;  g=mid; b=lo }
	return rgb(r,g,b,alpha)

/turf/proc/faels_get_color()
	var/color = null
	if (faels_lights)
		while (faels_lights.Remove(null))
			/* do nothing */ ;
		if (faels_lights.len==0)
			faels_lights = null
	/*
	Using color cylinder as model.
	All light sources are computed as sum of vectors inside of cylinder.
	To get the vector we're swithing from radial coordinates of color to cartesian coordinates
	*/
	var/sin_hue = 0
	var/cos_hue = 0
	var/lux_white = 0 //total luminosity of white light sources, lux
	var/lux_color = 0 //total luminosity of color light sources, lux

	for (var/atom/light in faels_lights)
		if (isnull(light.faels_hue))
			lux_white += FaELS_METERS2LX(faels_lights[light])
		else
			var/lux_current = FaELS_METERS2LX(faels_lights[light]) //luminosity of current light source
			var/hue_angle = light.faels_hue*360/1536
			sin_hue += lux_current*sin(hue_angle)
			cos_hue += lux_current*cos(hue_angle)
			lux_color += lux_current


	var/hue
	var/saturation
	var/value
	var/alpha
	#ifdef FaELS_DEBUG
	var/_vector_lenght
	var/_arcsin = "n/a"
	var/angle = "n/a"
	#endif
	if (lux_color)
		sin_hue /= lux_color
		cos_hue /= lux_color
		var/vector_lenght = sqrt(sin_hue**2 + cos_hue**2)
		if (vector_lenght<1) //colors are (partially) combined into white (e.g. red+green+blue)
			var/additional_white = lux_color*(1-vector_lenght)
			lux_color-=additional_white
			lux_white+=additional_white
		if (vector_lenght)
			hue = arcsin(sin_hue/vector_lenght) //normalize vector and get angle
			if (sin_hue>=0) //arcsin() returns [-90;90], need to convert that to [0;360)
				if (cos_hue>=0)
					/*not need to do anything*/;
				else
					hue = 180-hue
			else
				if (cos_hue>0)
					hue = 360+hue //hue is negative here
				else
					hue = 180+(-hue) //hue is negative here
			#ifdef FaELS_DEBUG
			angle = hue
			_arcsin = arcsin(sin_hue/vector_lenght)
			_vector_lenght = vector_lenght
			#endif
			hue = round(hue*1536/360, FaELS_HUE_ROUNDING) //normalize vector and convert to hue

	var/lux_total = lux_color+lux_white
	faels_litness = lux_total?FaELS_LX2METERS(lux_total):0
	faels_litness = max(min(faels_litness, FaELS_MAX_LUMINOSITY), 0)

	var/amount = lux_total?(lux_color/lux_total):0

	switch(faels_litness)
		if (0)
			return "#000000FF" //black square
		if (1 to FaELS_SHINE_TRESHOLD-1)
			var/litness = min(faels_litness/FaELS_DARK_SHADES, 1)
			var/iamount = 1-amount
			saturation = 255 //min(round(256 * (1-amount*faels_litness/8), 32), 255)
			value = k_shade_v + amount*k_shade_v_a + litness*k_shade_v_l + litness*amount*k_shade_v_la
			value = max(min(round(value*FaELS_DARK_SHADES)*255/FaELS_DARK_SHADES, 255), 0)
			alpha = k_shade_a + amount*k_shade_a_a + litness*k_shade_a_l + litness*amount*k_shade_a_la
			alpha = max(min(round(alpha*FaELS_DARK_SHADES)*255/FaELS_DARK_SHADES, 255), 0)
	/*
			value = min(round(256 * (amount/4*faels_litness/7), 32), 255)
			alpha = min(round(256 * (1 - faels_litness/8*(1 - amount/4)), 32), 255)
	*/
	/*
		if (8 to FaELS_SHINE_TRESHOLD)
			if (!lux_color)
				return // null //color = "none"
			saturation = 255
			value = 255
			alpha = round(256*amount/8, 32)
	*/
		if (FaELS_SHINE_TRESHOLD to FaELS_SHINE_TRESHOLD+FaELS_LIGHT_SHINES)
			var/litness = min((faels_litness-FaELS_SHINE_TRESHOLD)/FaELS_LIGHT_SHINES, 1)
			saturation = k_shine_s + amount*k_shine_s_a + litness*k_shine_s_l + litness*amount*k_shine_s_la
			saturation = max(min(round(saturation*FaELS_LIGHT_SHINES)*255/FaELS_LIGHT_SHINES, 255), 0)
			value = 255
			alpha = k_shine_a + amount*k_shine_a_a + litness*k_shine_a_l + litness*amount*k_shine_a_la
			alpha = max(min(round(alpha*FaELS_LIGHT_SHINES)*255/FaELS_LIGHT_SHINES, 255), 0)
		else
			saturation = amount
			saturation = max(min(round(saturation*4)*64, 255), 0)
			value = 255
			alpha = 255
		/*
			saturation = min(round(256*(amount/4), 32), 255)
			value = 255
			alpha = min(round(256 * ((faels_litness-FaELS_SHINE_TRESHOLD)/8*(1 - amount/4)), 32), 255)
			alpha = min(round(256*(amount/8+(faels_litness-FaELS_SHINE_TRESHOLD)*3/8), 32), 255)
		else
			saturation = min(round(256*(amount/4), 32), 255)
			value = 255
			alpha = 7*32
			*/
	color = faels_hsv2rgb(hue,saturation,value,alpha)
	#ifdef FaELS_DEBUG
	var/mob/M = locate(/mob) in src
	if (M && M.client)
		world << "\b DEBUG: FaELS: color=[color]; hue/sat/val=[hue],[saturation],[value]; sincos=[sin_hue],[cos_hue]; arcsin=[_arcsin]; angle=[angle]; vector_lenght=[_vector_lenght]"
	#endif

	return color
#else
/turf/proc/faels_get_color()
	var/color = null
	var/lux = 0
	for (var/light in faels_lights)
		if (isnull(light))
			faels_lights-=light
			continue
		lux += FaELS_LX2METERS(faels_lights[light])
	faels_litness = lux ? FaELS_LX2METERS(lux) : 0
	if (faels_lights)
		if (faels_lights.len==0)
			del(faels_lights)
	switch(faels_litness)
		if (0 to 6)
			color = rgb(0,0,0,256-(faels_litness+1)*32)
		if (7 to FaELS_TRESHOLD)
			return // null //color = "none"
		if (FaELS_TRESHOLD+1 to FaELS_TRESHOLD+8)
			color = rgb(255,255,255,min(((faels_litness-(FaELS_TRESHOLD+1))+1)*32, 255))
		else
			if (faels_litness<0) //shouldn't happen
				color = rgb(0,0,0,7*32)
			else
				color = rgb(255,255,255,7*32)

	return color
#endif

/turf/proc/faels_apply_overlay()
	var/area/Loc = loc
	FaELS_ASSERT(isarea(Loc))
	if (!Loc.lighting_use_dynamic)
		return
	var/color = faels_get_color()
	if (!color)
		if (Loc != Loc.master)
			Loc.master.contents += src
	else
		var/ltag = copytext(Loc.tag,1,findtext(Loc.tag,"/faels_")) + "/faels_[color]"
		if(Loc.tag!=ltag)	//skip if already in this area
			var/area/A = locate(ltag)	// find an appropriate area
			if(!A)
				A = new Loc.type(null, color, Loc, ltag)    // create area if it wasn't found
			A.contents += src	// move the turf into the area
/*
	if (faels_luminosity==0 && opacity == 0)
		luminosity = !isnull(faels_lights) //hack to see enlighted turfs while being in shadows
*/
	#ifdef FaELS_DEBUG
	faels_apply_overlay_debug()
	#endif
	return

/turf/space/faels_apply_overlay() //override
	var/area/Loc = loc
	if (isarea(Loc.master) && Loc != Loc.master)
		Loc.master.contents += src
	//if (!Loc.sd_lighting)
	//	return
	#ifdef FaELS_DEBUG
	if (faels_overlay_debug)
		overlays.Remove(faels_overlay_debug)
	if (!FaELS.show_numbers)
		faels_overlay_debug = null
		return
	faels_get_color() //return value not used, called for side effects which is setting faels_litness up
	if (faels_litness)
		faels_overlay_debug = FaELS.numbers[max(1,min(faels_litness, 100))+1]
		overlays.Add(faels_overlay_debug)
	else
		faels_overlay_debug = null
	#endif
	return

#ifdef FaELS_DEBUG
/turf/proc/faels_apply_overlay_debug()
	if (faels_overlay_debug)
		overlays.Remove(faels_overlay_debug)
	if (/*faels_litness &&*/ FaELS.show_numbers)
		faels_overlay_debug = FaELS.numbers[max(0,min(faels_litness, 100))+1]
		overlays.Add(faels_overlay_debug)
	else
		faels_overlay_debug = null
	return
/*
/turf/simulated/wall/faels_apply_overlay()
	faels_apply_overlay_debug()
	return
/turf/simulated/rwall/faels_apply_overlay()
	faels_apply_overlay_debug()
	return
*/
#endif
/* ================= END OF VISUAL ================== */


/* ================= UTILS ================== */

/proc/FaELS_get_turf(var/atom/A) //TODO: wrap into macro
	var/turf/T = A
	for (var/sanity = 500, sanity>0, sanity--)
		if (isturf(T))
			return T
		if (istype(T.loc,/obj)) //something in a box? //TODO: handle transparent containers
			return
		if (istype(T.loc,/mob) && istype(T,/mob))  //someone got eaten?
			return
		if (isnull(T.loc)) //something goes wrong //no, its okay. There in nowhere are lots of things.
		/*
			#ifdef FaELS_DEBUG
			if (A==T)
				world << "\b DEBUG: FaELS ERROR: [A] is nowhere!"
				CRASH("FaELS ERROR: [A] is nowhere!")
			else
				world << "\b DEBUG: FaELS ERROR: [A] is in [T] which is nowhere!"
				CRASH("FaELS ERROR: [A] is in [T] which is nowhere!")
			#endif
		*/
			return
		T = T.loc
	#ifdef FaELS_DEBUG
	if (A==T)
		world << "\b DEBUG: FaELS ERROR: [A] is in [T]... OH SHI~"
		CRASH("FaELS ERROR: [A] is in [T]... OH SHI~")
	else
		world << "\b DEBUG: FaELS ERROR: [A] is in [T] which is in... OH SHI~"
		CRASH("FaELS ERROR: [A] is in [T] which is in... OH SHI~")
	#endif
	return

/* ================= END OF UTILS ================== */
/* ============ END OF FaELS INTERNALS ============*/



/* ================= DEBUGGING TOOLS ================== */


/datum/FaELS/proc/report()
	var/num_lights = 0
	var/num_luminous_mobs = 0
	var/num_space_turfs = 0
	//var/num_lit_turfs_1 = 0
	//var/num_lit_turfs_2 = 0
	var/num_lit_turfs = 0
	for (var/atom/A)
		if (A.faels_luminosity)
			num_lights++
			if (ismob(A))
				num_luminous_mobs++
		if (istype(A, /turf))
			if (istype(A, /turf/space))
				num_space_turfs++
			var/turf/T = A
			if (T.faels_litness)
				num_lit_turfs++
	return {"
\b FaELS REPORT
num_lights: [num_lights]
num_luminous_mobs: [num_luminous_mobs]
num_space_turfs: [num_space_turfs]
num_lit_turfs: [num_lit_turfs]
icons([icons.len]): [english_list(icons)]
turf_data_storage: [turf_data_storage.len]
"}

/mob/verb/faels_report()
	set name = "FaELS DEBUG"
	set category = "Debug"
	src << FaELS.report()

/mob/verb/faels_refresh()
	set name = "FaELS Refresh"
	set category = "Debug"
	world << "\red FaELS Refresh has been initiated by [usr.key]"
	sleep(0) //flush
	var/start_time
	start_time = world.timeofday
	for (var/turf/T)
		T.faels_apply_overlay()
	world << "\red \b FaELS Refresh finished in [(world.timeofday-start_time)/10] seconds!"

/mob/verb/faels_reset()
	set name = "FaELS RESET"
	set category = "Debug"
	world << "\red FaELS RESET has been initiated by [usr.key]"
	sleep(5) //flush
	//world.loop_checks=0 //is not allowed :(
	FaELS.force_delay_updates = 1
	var/start_time
	start_time = world.timeofday
	FaELS.lights_to_update.len = 0
	FaELS.turfs_to_update.len = 0
	FaELS.turf_data_storage.len = 0

	for (var/turf/T)
		del(T.faels_lights)
		T.faels_apply_overlay()
	for (var/atom/A)
		if (isarea(A))
			continue
		A.faels_pending_luminosity = -1
		A.faels_flags = 0
		A.luminosity = A.faels_luminosity
		A.faels_luminosity = 0

	world << "\red \b FaELS RESET finished in [(world.timeofday-start_time)/10] seconds!"
	FaELS.initialize()

	FaELS.force_delay_updates = 0
	//world.loop_checks=1
	return

/*
 * Okay now I see the oview() is buggy as dirty whore.
 * the oview(1) can see zero turfs while the oview(2) sees 20 turfs. Fuck this shit.
 * Added later: maybe I was wrong here. I didn't know oview() returns /obj/ too.
 */
/*
/turf/verb/my_oview()
	set name="FaELS my_oview"
	set category = "Debug"
	set src in world
	var/V1 = 0
	for (var/turf/T1 in oview(1, src))
		V1++
		new/obj/item/device/radio/headset(T1)
	var/V2 = 0
	for (var/turf/T1 in oview(2, src))
		V2++
		new/obj/item/weapon/reagent_containers/food/snacks/donut(T1)
	world << "DEBUG: FaELS: V1=[V1], V2=[V2]"
*/

/*
/turf/verb/makewall()
	set name="FaELS makewall"
	set category = "Debug"
	set src in world
	var/list/l = new
	l += src
	src.ReplaceWithWall()
	for (var/i in l)
		usr << "l\[[i]\] = [l[i]]"
*/


/turf/verb/faels_welding()
	set name="FaELS faels_welding"
	set category = "Debug"
	set src in world
	spawn(1)
		var/old_f_l = src.faels_luminosity
		var/const/L = 5
		var/const/LR = 4
		FaELS.set_luminosity(src, L)
		for(var/i=0 to 6)
			sleep(rand(2,5))
			FaELS.set_luminosity(src, rand(L,L+LR))
			sleep(rand(2,10))
			FaELS.set_luminosity(src, L)
		FaELS.set_luminosity(src, old_f_l)
	return


/obj/item/device/flashlight/white
	name = "white flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = null
	icon_state = "flight1"
	on = 1

#ifdef FaELS_COLOR

/obj/item/device/flashlight/red
	name = "red flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/yellow
	name = "yellow flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0x100
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/green
	name = "green flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0x200
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/cyan
	name = "cyan flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0x300
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/blue
	name = "blue flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0x400
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/magenta
	name = "magenta flashlight"
	brightness_on = 7
	luminosity = 7
	faels_hue = 0x500
	icon_state = "flight1"
	on = 1
//=====

/obj/item/projectile/energy
	luminosity = 3
	faels_hue = 0

/obj/item/projectile/beam
	luminosity = 3

/obj/item/projectile/beam/heavylaser
	faels_hue = 0

/obj/item/projectile/beam/pulse
	faels_hue = 0x400

/obj/item/projectile/beam/deathlaser
	faels_hue = 0x400

/obj/item/projectile/energy

/obj/item/projectile/energy/electrode
	faels_hue = 0x50
	luminosity = 1

/obj/item/projectile/energy/dart
	luminosity = 1
	faels_hue = 0x200

/obj/item/projectile/energy/bolt
	faels_hue = 0x400

/obj/item/projectile/energy/bolt/large
	faels_hue = 0x400

#endif /*FaELS_COLOR*/






/obj/item/device/flashlight/big
	name = "big flashlight"
	brightness_on = 10 //luminosity when on
	luminosity = 10
	icon_state = "flight1"
	on = 1

/obj/item/device/flashlight/uber
	name = "Der uber Taschenlampe"
	desc = "hergestellt in Uberwald"
	brightness_on = FaELS_MAX_LUMINOSITY
	luminosity = FaELS_MAX_LUMINOSITY
	icon_state = "flight1"
	on = 1

#ifdef FaELS_DEBUG

/mob/verb/faels_numbers()
	set name = "FaELS toggle numbers"
	set category = "Debug"
	FaELS.show_numbers = !FaELS.show_numbers
	world << "\b Litness values are [FaELS.show_numbers?"shown":"hidden"] now."
	for (var/turf/T)
		T.faels_apply_overlay()

#endif /*FaELS_DEBUG*/

/mob/verb/faels_calibrating_explosion()
	set name = "FaELS calibrating explosion"
	set category = "Debug"
	var/turf/epicenter = locate(113, 128, 1) //AI
	var/start_time
	message_admins("\blue [ckey] creating an admin explosion at at [coords2text(epicenter)] \[[epicenter.loc]\].")
	sleep(0)
	start_time = world.timeofday
	explosion(epicenter, 3, 7, 14, 15)
	world << "\red \b FaELS calibrating explosion processed in [(world.timeofday-start_time)/10] seconds!"
	return

/mob/verb/faels_calibrating_explosion2()
	set name = "FaELS calibrating explosion 2"
	set category = "Debug"
	var/turf/epicenter = locate(113, 128, 1) //AI
	var/start_time
	message_admins("\blue [ckey] creating an admin explosion at at [coords2text(epicenter)] \[[epicenter.loc]\].")
	sleep(0)
	start_time = world.timeofday
	FaELS.force_delay_updates = 1
	explosion(epicenter, 3, 7, 14, 15)
	sleep(10)
	FaELS.force_delay_updates = 0
	FaELS.do_update()
	world << "\red \b FaELS calibrating explosion 2 processed in [(world.timeofday-start_time)/10] seconds!"
	return


/* ================= END OF DEBUGGING TOOLS ================== */

//some cleaning up
#undef FaELS_DEBUG

#undef FaELS_NUMBERS_FILE
#undef FaELS_DELAY
#undef FaELS_COLOR

#undef FaELS_HUE_LIMIT

#undef FaELS_TRESHOLD
#undef FaELS_MAX_LUMINOSITY

#undef FaELS_HUE_ROUNDING
#undef FaELS_LOGBASE

#undef FaELS_SMALL_MAP

#undef FaELS_SHEDULED_TURF
#undef FaELS_SHEDULED_LIGHT
#undef FaELS_OP_SET_LUM
#undef FaELS_OP_OPACITY_SET
#undef FaELS_OP_OPACITY_CLR

#undef FaELS_ASSERT

#undef FaELS_UPDATE
#undef RANGE_TURFS
#undef HYPOTENUSE

#undef FaELS_LX2METERS
#undef FaELS_METERS2LX
