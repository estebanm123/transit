class_name TrafficDebugger extends RefCounted

var _traffic: Traffic


func init(traffic: Traffic) -> void:
    _traffic = traffic


func _carWorldPos(car: Traffic.Car) -> Vector2:
    return Vector2(
        lerpf(_traffic._vertStreetX[car.fromVertStreet],
                _traffic._vertStreetX[car.toVertStreet], car.progress) + car.laneOffset.x,
        lerpf(_traffic._horzStreetY[car.fromHorzStreet],
                _traffic._horzStreetY[car.toHorzStreet], car.progress) + car.laneOffset.y)


func debugCarsNear(worldPos: Vector2, radius: float) -> void:
    var out: PackedStringArray = []
    out.append("=== DEBUG CLICK world=(%.1f,%.1f) radius=%.0f ===" % [
            worldPos.x, worldPos.y, radius])

    var nearby: Array[Traffic.Car] = []
    for car: Traffic.Car in _traffic._cars:
        if _carWorldPos(car).distance_to(worldPos) <= radius:
            nearby.append(car)
    out.append("Cars in radius: %d" % nearby.size())

    for car: Traffic.Car in nearby:
        var pos: Vector2 = _carWorldPos(car)
        var dist: float = pos.distance_to(worldPos)
        var isHoriz: bool = (car.toHorzStreet == car.fromHorzStreet)
        var segKey := Vector4i(
                car.fromVertStreet, car.fromHorzStreet, car.toVertStreet, car.toHorzStreet)

        out.append("")
        out.append("  [Car pos=(%.1f,%.1f) dist=%.1f]" % [pos.x, pos.y, dist])
        out.append("    seg: (v%d,h%d)→(v%d,h%d) [%s] len=%.1f" % [
                car.fromVertStreet, car.fromHorzStreet,
                car.toVertStreet, car.toHorzStreet,
                "H" if isHoriz else "V", car.segLength])
        out.append("    progress=%.4f  speed=%.2f  desired=%.2f" % [
                car.progress, car.currentSpeed, car.desiredSpeed])

        if car.leader != null:
            var gap: float = (car.leader.progress - car.progress) * car.segLength \
                    - Traffic.CarLength
            out.append("    leader: prog=%.4f spd=%.2f gap=%.2fu" % [
                    car.leader.progress, car.leader.currentSpeed, gap])
        else:
            out.append("    leader: NONE (front of segment)")
            var xExits: Array = _traffic._getExitSegments(car.toVertStreet, car.toHorzStreet,
                    car.fromVertStreet, car.fromHorzStreet)
            var xGoalPreferred: Array = _traffic._getGoalPreferredExit(car)
            var xChosen: Array = _traffic._getChosenExit(car)
            for xExit: Array in xExits:
                var xKey := Vector4i(car.toVertStreet, car.toHorzStreet, xExit[0], xExit[1])
                var xTail: Traffic.Car = _traffic._segmentMap.get(xKey, null)
                var xMark: String = " [CHOSEN]" if not xChosen.is_empty() \
                        and xExit[0] == xChosen[0] and xExit[1] == xChosen[1] else ""
                if xTail != null:
                    var xCrossGap: float = (1.0 - car.progress) * car.segLength \
                            + xTail.progress * xTail.segLength - Traffic.CarLength
                    out.append("    xseg (v%d,h%d→v%d,h%d)%s: tail.prog=%.4f spd=%.2f crossGap=%.2fu" % [
                            xKey.x, xKey.y, xKey.z, xKey.w, xMark,
                            xTail.progress, xTail.currentSpeed, xCrossGap])
                else:
                    out.append("    xseg (v%d,h%d→v%d,h%d)%s: empty" % [
                            xKey.x, xKey.y, xKey.z, xKey.w, xMark])
            if not xChosen.is_empty():
                var xChosenKey := Vector4i(car.toVertStreet, car.toHorzStreet,
                        xChosen[0], xChosen[1])
                var xChosenTail: Traffic.Car = _traffic._segmentMap.get(xChosenKey, null)
                var xBoxThresh: float = 0.0
                var xBoxClear: bool = _traffic._chosenExitHasBoxClearance(car, xChosen)
                if xChosenTail != null:
                    xBoxThresh = minf(1.0,
                            (Traffic.IntersectionBoxDepth + Traffic.CarLength)
                            / xChosenTail.segLength)
                out.append("    chosenExitBoxClear=%s thresh=%.4f tailProg=%s" % [
                        str(xBoxClear), xBoxThresh,
                        "%.4f" % xChosenTail.progress if xChosenTail != null else "NONE"])
                if not xGoalPreferred.is_empty() \
                    and (xGoalPreferred[0] != xChosen[0] or xGoalPreferred[1] != xChosen[1]):
                    out.append("    chosenExitFallback: goal=(v%d,h%d) active=(v%d,h%d)" % [
                        xGoalPreferred[0], xGoalPreferred[1], xChosen[0], xChosen[1]])
        if car.follower != null:
            out.append("    follower: prog=%.4f spd=%.2f" % [
                    car.follower.progress, car.follower.currentSpeed])
        else:
            out.append("    follower: NONE (tail of segment)")

        var mapTail: Traffic.Car = _traffic._segmentMap.get(segKey, null)
        var mapFront: Traffic.Car = _traffic._segmentFront.get(segKey, null)
        out.append("    segMap: isTail=%s(follower==null:%s)  isFront=%s(leader==null:%s)" % [
                str(mapTail == car), str(car.follower == null),
                str(mapFront == car), str(car.leader == null)])

        var lightKey := Vector2i(car.toVertStreet, car.toHorzStreet)
        var hasLight: bool = _traffic._trafficLights.has(lightKey)
        var redLight: bool = false
        if hasLight:
            var light: Dictionary = _traffic._trafficLights[lightKey]
            var isEW: bool = isHoriz
            redLight = (isEW and light.phase == Traffic.PhaseNS) \
                    or (not isEW and light.phase == Traffic.PhaseEW)
            var elapsed: float = _traffic._time - light.lastChanged
            out.append("    light: phase=%s elapsed=%.1fs red=%s" % [
                    "NS" if light.phase == Traffic.PhaseNS else "EW", elapsed, str(redLight)])
        else:
            out.append("    light: none")

        if car.reservedIntersection != Traffic.NoIntersection:
            out.append("    reservation: (v%d,h%d) held=%s" % [
                    car.reservedIntersection.x, car.reservedIntersection.y,
                    str(_traffic._carHoldsIntersection(car, car.reservedIntersection))])
            if car.reservedIntersection != lightKey:
                var staleThreshold: float = Traffic.IntersectionBoxDepth / car.segLength
                out.append("    reservationScope: previous_intersection clearThresh=%.4f staleNow=%s" % [
                        staleThreshold, str(car.progress >= staleThreshold)])
        else:
            out.append("    reservation: none")
        var lockOwner: Traffic.Car = _traffic._intersectionLocks.get(lightKey, null)
        if lockOwner != null:
            out.append("    lockOwner: seg=(v%d,h%d)→(v%d,h%d) prog=%.4f self=%s" % [
                    lockOwner.fromVertStreet, lockOwner.fromHorzStreet,
                    lockOwner.toVertStreet, lockOwner.toHorzStreet,
                    lockOwner.progress, str(lockOwner == car)])
        else:
            out.append("    lockOwner: none")

        var stopT: float = maxf(0.0, 1.0 - Traffic.StopOffset / car.segLength)
        var brakeStartT: float = stopT - Traffic.BrakingDistance / car.segLength
        var projectedProgress: float = car.progress \
            + maxf(car.currentSpeed, car.desiredSpeed) * _traffic._lastDelta / car.segLength
        var intersectionBlocked: bool = false
        var intCheckStatus: String
        var holdsIntersection: bool = _traffic._carHoldsIntersection(car, lightKey)
        var needsIntersectionControl: bool = holdsIntersection \
                or car.progress > stopT \
                or projectedProgress > stopT
        var chosenExit: Array = []
        var chosenExitHasBoxClearance: bool = true
        if car.leader == null:
            chosenExit = _traffic._getChosenExit(car)
            chosenExitHasBoxClearance = _traffic._chosenExitHasBoxClearance(car, chosenExit)
        if redLight:
            intCheckStatus = "no(red)"
        elif holdsIntersection:
            intCheckStatus = "reserved"
        elif not needsIntersectionControl:
            intCheckStatus = "no(stopline)"
        else:
            var locker: Traffic.Car = _traffic._intersectionLocks.get(lightKey, null)
            if locker != null and locker != car:
                intersectionBlocked = true
                intCheckStatus = "locked"
            elif car.progress > stopT and car.leader == null:
                intCheckStatus = "reclaim"
            elif car.progress <= stopT and car.leader != null:
                intersectionBlocked = true
                intCheckStatus = "no(front_car)"
            else:
                intersectionBlocked = not _traffic._isIntersectionClear(
                        car.toVertStreet, car.toHorzStreet, isHoriz)
                if not intersectionBlocked and not chosenExitHasBoxClearance:
                    intersectionBlocked = true
                    intCheckStatus = "exit_boxed"
                if car.progress > stopT:
                    intCheckStatus = "committed(%s)" % (
                            "blocked" if intersectionBlocked else "clear")
                elif intCheckStatus == "exit_boxed":
                    pass
                elif not intersectionBlocked and car.leader == null \
                        and projectedProgress > stopT:
                    intCheckStatus = "claim"
                else:
                    intCheckStatus = "yes"
        var shouldStop: bool = car.progress <= stopT \
                and (redLight or intersectionBlocked)
        var committedBlocked: bool = car.progress > stopT and car.progress < 1.0 \
                and intersectionBlocked
        var committedWithoutLock: bool = car.progress > stopT and not holdsIntersection
        var limiter: String = "none"
        var effSpeed: float = car.desiredSpeed
        if shouldStop:
            if car.progress > brakeStartT and stopT > brakeStartT:
                effSpeed = car.desiredSpeed \
                        * (stopT - car.progress) / (stopT - brakeStartT)
            limiter = "intersection"
        elif committedBlocked:
            effSpeed = 0.0
            limiter = "committed_block"
        if car.leader != null and car.leader.progress > car.progress:
            var dbgGap: float = (car.leader.progress - car.progress) \
                    * car.segLength - Traffic.CarLength
            if dbgGap <= 0.0:
                effSpeed = 0.0
                limiter = limiter + "+leader(gap<=0)" if limiter != "none" else "leader(gap<=0)"
            elif dbgGap < Traffic.BrakingDistance:
                var capped: float = minf(effSpeed, car.leader.currentSpeed)
                if capped < effSpeed:
                    limiter = limiter + "+leader" if limiter != "none" else "leader"
                effSpeed = capped
        if car.leader == null:
            var xdv2: int = car.toVertStreet - car.fromVertStreet
            var xdh2: int = car.toHorzStreet - car.fromHorzStreet
            var xKey2 := Vector4i(car.toVertStreet, car.toHorzStreet,
                    car.toVertStreet + xdv2, car.toHorzStreet + xdh2)
            var xTail2: Traffic.Car = _traffic._segmentMap.get(xKey2, null)
            if xTail2 != null:
                var xGap2: float = (1.0 - car.progress) * car.segLength \
                        + xTail2.progress * xTail2.segLength - Traffic.CarLength
                if xGap2 <= 0.0:
                    effSpeed = 0.0
                    limiter = limiter + "+next_seg(gap<=0)" if limiter != "none" \
                            else "next_seg(gap<=0)"
                elif xGap2 < Traffic.BrakingDistance:
                    var capped2: float = minf(effSpeed, xTail2.currentSpeed)
                    if capped2 < effSpeed:
                        limiter = limiter + "+next_seg" if limiter != "none" else "next_seg"
                    effSpeed = capped2
        out.append(("    stopT=%.4f brakeStartT=%.4f  red=%s intCheck=%s intBlocked=%s" \
                + " shouldStop=%s committedBlocked=%s  limiter=%s effSpd=%.2f") % [
                stopT, brakeStartT,
                str(redLight), intCheckStatus, str(intersectionBlocked), str(shouldStop),
                str(committedBlocked), limiter, effSpeed])
        if committedWithoutLock:
            out.append("    anomaly: committed_without_lock")

        var dv: int = car.toVertStreet
        var dh: int = car.toHorzStreet
        var departing: Array[Vector4i]
        var arriving: Array[Vector4i]
        if isHoriz:
            departing = [Vector4i(dv, dh, dv, dh + 1), Vector4i(dv, dh, dv, dh - 1)]
            arriving = [Vector4i(dv, dh - 1, dv, dh), Vector4i(dv, dh + 1, dv, dh)]
        else:
            departing = [Vector4i(dv, dh, dv + 1, dh), Vector4i(dv, dh, dv - 1, dh)]
            arriving = [Vector4i(dv - 1, dh, dv, dh), Vector4i(dv + 1, dh, dv, dh)]
        out.append("    intersection box (v%d,h%d):" % [dv, dh])
        for key: Vector4i in departing:
            var tail: Traffic.Car = _traffic._segmentMap.get(key, null)
            if tail == null:
                out.append("      depart (%d,%d)→(%d,%d): empty" % [key.x, key.y, key.z, key.w])
            else:
                var bT: float = Traffic.IntersectionBoxDepth / tail.segLength
                out.append(
                        ("      depart (%d,%d)→(%d,%d): tail.prog=%.4f spd=%.2f" \
                        + " boxThresh=%.4f inBox=%s moving=%s → %s") % [
                        key.x, key.y, key.z, key.w,
                        tail.progress, tail.currentSpeed, bT,
                        str(tail.progress < bT), str(tail.currentSpeed > 0.0),
                        "BLOCKING" if tail.progress < bT and tail.currentSpeed > 0.0 \
                        else ("IN_BOX_STOPPED" if tail.progress < bT else "clear")])
        for key: Vector4i in arriving:
            var front: Traffic.Car = _traffic._segmentFront.get(key, null)
            if front == null:
                out.append("      arrive (%d,%d)→(%d,%d): empty" % [key.x, key.y, key.z, key.w])
            else:
                var slT: float = 1.0 - Traffic.StopOffset / front.segLength
                var pastStop: bool = front.progress >= slT
                out.append(
                        ("      arrive (%d,%d)→(%d,%d): front.prog=%.4f spd=%.2f" \
                        + " stopLineT=%.4f pastStop=%s moving=%s → %s") % [
                        key.x, key.y, key.z, key.w,
                        front.progress, front.currentSpeed, slT,
                        str(pastStop), str(front.currentSpeed > 0.0),
                        "BLOCKING" if pastStop and front.currentSpeed > 0.0 \
                        else ("COMMITTED_STOPPED" if pastStop else "clear")])

    out.append("")
    out.append("--- Overlaps ---")
    var anyOverlap: bool = false
    for car: Traffic.Car in nearby:
        var pos: Vector2 = _carWorldPos(car)
        var carIsH: bool = (car.toHorzStreet == car.fromHorzStreet)
        var half: float = Traffic.CarLength * 0.5
        var halfW: float = Traffic.CarWidth * 0.5
        var carRect: Rect2 = Rect2(pos.x - half, pos.y - halfW, Traffic.CarLength, Traffic.CarWidth) \
                if carIsH \
                else Rect2(pos.x - halfW, pos.y - half, Traffic.CarWidth, Traffic.CarLength)
        var carKey := Vector4i(
                car.fromVertStreet, car.fromHorzStreet, car.toVertStreet, car.toHorzStreet)
        for other: Traffic.Car in _traffic._cars:
            if other == car:
                continue
            var otherPos: Vector2 = _carWorldPos(other)
            var otherIsH: bool = (other.toHorzStreet == other.fromHorzStreet)
            var otherRect: Rect2 = Rect2(
                    otherPos.x - half, otherPos.y - halfW,
                    Traffic.CarLength, Traffic.CarWidth) if otherIsH \
                    else Rect2(otherPos.x - halfW, otherPos.y - half,
                    Traffic.CarWidth, Traffic.CarLength)
            if carRect.intersects(otherRect):
                var otherKey := Vector4i(other.fromVertStreet, other.fromHorzStreet,
                        other.toVertStreet, other.toHorzStreet)
                out.append(
                        ("  %s: (v%d,h%d→v%d,h%d) p=%.4f spd=%.2f  ↔" \
                        + "  (v%d,h%d→v%d,h%d) p=%.4f spd=%.2f") % [
                        "SAME_SEG" if otherKey == carKey else "CROSS_SEG",
                        carKey.x, carKey.y, carKey.z, carKey.w,
                        car.progress, car.currentSpeed,
                        otherKey.x, otherKey.y, otherKey.z, otherKey.w,
                        other.progress, other.currentSpeed])
                anyOverlap = true
    if not anyOverlap:
        out.append("  none")

    out.append("")
    out.append("--- Intersections in radius ---")
    var anyLight: bool = false
    for lightKey: Vector2i in _traffic._trafficLights:
        var ix: float = _traffic._vertStreetX[lightKey.x]
        var iy: float = _traffic._horzStreetY[lightKey.y]
        if Vector2(ix, iy).distance_to(worldPos) > radius:
            continue
        anyLight = true
        var light: Dictionary = _traffic._trafficLights[lightKey]
        var elapsed: float = _traffic._time - light.lastChanged
        var phaseDuration: float
        if light.arterialPhase < 0:
            phaseDuration = Traffic.PhaseDuration
        elif light.phase == light.arterialPhase:
            phaseDuration = Traffic.PhaseArterialDuration
        else:
            phaseDuration = Traffic.PhaseNonArterialDuration
        var remaining: float = phaseDuration - elapsed
        var artLabel: String = "none"
        if light.arterialPhase == Traffic.PhaseNS:
            artLabel = "NS"
        elif light.arterialPhase == Traffic.PhaseEW:
            artLabel = "EW"
        out.append("  light (v%d,h%d) pos=(%.1f,%.1f)" % [lightKey.x, lightKey.y, ix, iy])
        out.append("    phase=%s  arterial=%s  elapsed=%.1fs  remaining=%.1fs / %.0fs" % [
                "NS" if light.phase == Traffic.PhaseNS else "EW",
                artLabel, elapsed, remaining, phaseDuration])
        var nsCount: int = 0
        var ewCount: int = 0
        var nsWaiting: int = 0
        var ewWaiting: int = 0
        for seg: Vector4i in [
                Vector4i(lightKey.x, lightKey.y - 1, lightKey.x, lightKey.y),
                Vector4i(lightKey.x, lightKey.y + 1, lightKey.x, lightKey.y)]:
            var front: Traffic.Car = _traffic._segmentFront.get(seg, null)
            if front != null:
                nsCount += 1
                if front.currentSpeed == 0.0:
                    nsWaiting += 1
        for seg: Vector4i in [
                Vector4i(lightKey.x - 1, lightKey.y, lightKey.x, lightKey.y),
                Vector4i(lightKey.x + 1, lightKey.y, lightKey.x, lightKey.y)]:
            var front: Traffic.Car = _traffic._segmentFront.get(seg, null)
            if front != null:
                ewCount += 1
                if front.currentSpeed == 0.0:
                    ewWaiting += 1
        out.append("    approaching: NS=%d (waiting=%d)  EW=%d (waiting=%d)" % [
                nsCount, nsWaiting, ewCount, ewWaiting])
    if not anyLight:
        out.append("  none (no traffic lights in radius)")

    print("\n".join(out))
