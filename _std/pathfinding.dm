/proc/AStar(start, end, adjacent, heuristic, maxtraverse = 30, adjacent_param = null, exclude = null)
	if(isnull(end) || isnull(start))
		return
	var/list/open = list(start), list/nodeG = list(), list/nodeParent = list(), P = 0
	while (P++ < length(open))
		var/T = open[P], TG = nodeG[T]
		if (T == end)
			var/list/R = list()
			while (T)
				R.Insert(1, T)
				T = nodeParent[T]
			return R
		var/list/other = call(T, adjacent)(adjacent_param)
		for (var/next in other)
			if ((next in open) || next == exclude) continue
			var/G = TG + other[next], F = G + call(next, heuristic)(end)
			for (var/i = P; i <= length(open);)
				if (i++ == length(open) || open[open[i]] >= F)
					open.Insert(i, next)
					open[next] = F
					break
			nodeG[next] = G
			nodeParent[next] = T

		if (P > maxtraverse)
			return


//#define DEBUG_ASTAR

/proc/cirrAstar(turf/start, turf/goal, min_dist=0, adjacent, maxtraverse = 30, adjacent_param = null, exclude = null)
	#ifdef DEBUG_ASTAR
	clearAstarViz()
	#endif

	var/list/turf/closedSet = list()
	var/list/turf/openSet = list(start)
	var/list/turf/cameFrom = list()

	var/list/gScore = list()
	var/list/fScore = list()
	gScore[start] = 0
	fScore[start] = GET_MANHATTAN_DIST(start, goal)
	var/traverse = 0

	while(length(openSet))
		var/turf/current = pickLowest(openSet, fScore)
		if(GET_MANHATTAN_DIST(current, goal) <= min_dist)
			return reconstructPath(cameFrom, current)

		openSet -= current
		closedSet += current
		var/list/turf/neighbors = getNeighbors(current, alldirs)
		for(var/turf/neighbor as() in neighbors)
			if(neighbor in closedSet)
				continue // already checked this one
			var/tentativeGScore = gScore[current] + GET_MANHATTAN_DIST(current, neighbor)
			if(!(neighbor in openSet))
				openSet += neighbor
			else if(tentativeGScore >= (gScore[neighbor] || 1.#INF))
				continue // this is not a better route to this node

			cameFrom[neighbor] = current
			gScore[neighbor] = tentativeGScore
			fScore[neighbor] = gScore[neighbor] + GET_MANHATTAN_DIST(neighbor, goal)
		traverse += 1
		if(traverse > maxtraverse)
			return null // it's taking too long, abandon
		LAGCHECK(LAG_LOW)
	return null // if we reach this part, there's no more nodes left to explore


/proc/pickLowest(list/options, list/values)
	if(!length(options))
		return null // you idiot
	var/lowestScore = 1.#INF
	for(var/option in options)
		if(option in values)
			var/score = values[option]
			if(score < lowestScore)
				lowestScore = score
				. = option

/proc/reconstructPath(list/cameFrom, turf/current)
	var/list/totalPath = list(current)
	while(current in cameFrom)
		current = cameFrom[current]
		totalPath += current
	// reverse the path
	. = list()
	for(var/i = length(totalPath) to 1 step -1)
		. += totalPath[i]
	#ifdef DEBUG_ASTAR
	addAstarViz(.)
	#endif
	return .

/proc/getNeighbors(turf/current, list/directions)
	. = list()
	// handle cardinals straightforwardly
	var/list/cardinalTurfs = list()
	for(var/direction in cardinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			cardinalTurfs["[direction]"] = 0 // can't pass
			if(T && checkTurfPassable(T))
				. += T
				cardinalTurfs["[direction]"] = 1 // can pass
	 //diagonals need to avoid the leaking problem
	for(var/direction in ordinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			if(T && checkTurfPassable(T))
				// check relevant cardinals
				var/clear = 1
				for(var/cardinal in cardinal)
					if(direction & cardinal)
						// this used to check each cardinal turf again but that's completely unnecessary
						if(!cardinalTurfs["[direction]"])
							clear = 0
				if(clear)
					. += T

// shamelessly stolen from further down and modified
/proc/checkTurfPassable(turf/T)
	if(!T)
		return 0 // can't go on a turf that doesn't exist!!
	if(T.density) // simplest case
		return 0
	for(var/atom/O in T.contents)
		if (O.density) // && !(O.flags & ON_BORDER)) -- fuck you, windows, you're dead to me
			// @FIXME this entire block of code does nothing
			// if (istype(O, /obj/machinery/door))
			// 	var/obj/machinery/door/D = O
			// 	if (D.isblocked())
			// 		return 0 // a blocked door is a blocking door
			// if (ismob(O))
			// 	var/mob/M = O
			// 	if (M.anchored)
			// 		return 0 // an anchored mob is a blocking mob
			// 	else
			return 0 // not a special case, so this is a blocking object
	return 1



#ifdef DEBUG_ASTAR
/var/static/list/astarImages = list()
/proc/clearAstarViz()
	for(var/client/C in clients)
		C.images -= astarImages
	astarImages = list()

/proc/addAstarViz(var/list/path)
	astarImages = list()
	for(var/turf/T in path)
		var/image/marker = image('icons/mob/screen1.dmi', T, icon_state="x3")
		marker.color="#0F8"
		astarImages += marker
	for(var/client/C in clients)
		C.images += astarImages
#endif










/******************************************************************/
// Navigation procs
// Used for A-star pathfinding

/// Returns the surrounding cardinal turfs with open links
/// Including through doors openable with the ID
/turf/proc/CardinalTurfsWithAccess(obj/item/card/id/ID)
	. = list()

	for(var/d in cardinal)
		var/turf/simulated/T = get_step(src, d)
		if (T?.pathable && !T.density)
			if(!LinkBlockedWithAccess(src, T, ID))
				. += T

/// Returns surrounding card+ord turfs with open links
/turf/proc/AllDirsTurfsWithAccess(obj/item/card/id/ID)
	. = list()

	for(var/d in alldirs)
		var/turf/simulated/T = get_step(src, d)
		//if(istype(T) && !T.density)
		if (T?.pathable && !T.density)
			if(!LinkBlockedWithAccess(src, T, ID))
				. += T

// Fixes floorbots being terrified of space
turf/proc/CardinalTurfsAndSpaceWithAccess(obj/item/card/id/ID)
	. = list()

	for(var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (T && (T.pathable || istype(T, /turf/space)) && !T.density)
			if(!LinkBlockedWithAccess(src, T, ID))
				. += T

var/static/obj/item/card/id/ALL_ACCESS_CARD = new /obj/item/card/id/captains_spare()

/turf/proc/AllDirsTurfsWithAllAccess()
	return AllDirsTurfsWithAccess(ALL_ACCESS_CARD)

/turf/proc/CardinalTurfsSpace()
	. = list()

	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (T && (T.pathable || istype(T, /turf/space)) && !T.density)
			if (!LinkBlockedWithAccess(src, T))
				. += T

// Returns true if a link between A and B is blocked
// Movement through doors allowed if ID has access
/proc/LinkBlockedWithAccess(turf/A, turf/B, obj/item/card/id/ID)
	. = FALSE
	if(A == null || B == null)
		return 1
	var/adir = get_dir(A,B)
	var/rdir = get_dir(B,A)
	if((adir & (NORTH|SOUTH)) && (adir & (EAST|WEST)))	//	diagonal
		var/iStep = get_step(A,adir&(NORTH|SOUTH))
		if(!LinkBlockedWithAccess(A,iStep, ID) && !LinkBlockedWithAccess(iStep,B,ID))
			return 0

		var/pStep = get_step(A,adir&(EAST|WEST))
		if(!LinkBlockedWithAccess(A,pStep,ID) && !LinkBlockedWithAccess(pStep,B,ID))
			return 0
		return 1

	if(!DirWalkableWithAccess(A,adir, ID, exiting_this_tile = 1))
		return 1

	var/DirWalkableB = DirWalkableWithAccess(B,rdir, ID)
	if(!DirWalkableB)
		return 1

	if (DirWalkableB == 2) //we found a door we can open! Let's open the door before we check the whole tile for dense objects below.
		return 0

	for (var/atom/O in B.contents)
		if (O.density)
			if (ismob(O))
				var/mob/M = O
				if (M.anchored)
					return 1
				return 0

			if (O.flags & ON_BORDER)
				if (rdir == O.dir)
					return 1
			else
				return 1

// Returns true if direction is accessible from loc
// If we found a door we could open, return 2 instead of 1.
// Checks doors against access with given ID
/proc/DirWalkableWithAccess(turf/loc,var/dir,var/obj/item/card/id/ID, var/exiting_this_tile = 0)
	. = TRUE
	for (var/obj/O in loc)
		if (O.density)
			if (O.object_flags & BOTS_DIRBLOCK)
				if (O.flags & ON_BORDER && dir == O.dir)//windoors and directional windows
					if (O.has_access_requirements())
						if (O.check_access(ID) == 0)
							return 0
						else
							return 2
					else
						return 2
				else if (!exiting_this_tile)		//other solid objects. dont bother checking if we are EXITING this tile
					if (O.has_access_requirements())
						if (O.check_access(ID) == 0)
							return 0
						else
							return 2
					else
						return 2
			else
				if (O.flags & ON_BORDER)
					if (dir == O.dir)
						return 0
				else if (!exiting_this_tile) //dont bother checking if we are EXITING this tile
					return 0





















/turf/proc
	AdjacentTurfs()
		. = list()
		for(var/turf/simulated/t in oview(src,1))
			if(!t.density)
				if(!LinkBlocked(src, t) && !TurfBlockedNonWindow(t))
					. += t

	AdjacentTurfsSpace()
		. = list()
		for(var/turf/t in oview(src,1))
			if(!t.density)
				if(!LinkBlocked(src, t) && !TurfBlockedNonWindow(t))
					. += t

	Distance(turf/t)
		return sqrt((src.x - t.x) ** 2 + (src.y - t.y) ** 2)

