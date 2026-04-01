local M = {}

-- Runtime state is the mod's working memory. It stores transient values such
-- as timers, cached game objects, and pending one-frame actions.
function M.new()
    return {
        caches = {
            playerCharacter = nil,
            playerController = nil,
            cameraManager = nil,
            aceKeyboard = nil,
        },
        status = {
            isCrouchTurn = false,
            lastCrouchTurnAt = os.clock(),
            isSheathing = false,
            lastSheathingAt = os.clock(),
            isSlingerAimActive = false,
            isAimMoving = false,
            managedFocusSession = false,
            suppressFocusUntilWeaponDrawn = false,
            ignoreSheatheUntil = 0,
            longSwordIaiActive = false,
            longSwordIaiUntil = 0,
            wasGameWindowFocused = nil,
            restoreFocusOnWindowRefocus = false,
            restoreFocusOnWindowRefocusUntil = 0,
            lastWindowRefocusRestoreAt = 0,
            refocusRestoreEligible = false,
            restoreFocusAfterShortcut = false,
            restoreFocusAfterShortcutAt = 0,
            restoreFocusAfterShortcutUntil = 0,
            lastObservedFocusAt = 0,
            wasTargeting = nil,
            wasWeaponDrawn = nil,
            wasOverwriteWeaponOnOffState = nil,
        },
        pending = {
            weaponDrawStage = 0,
            lastWeaponDrawRequestAt = 0,
            blockSnapStage = 0,
            lastBlockSnapRequestAt = 0,
        },
        camera = {
            suppressUntil = 0,
            blockSnapBypassUntil = 0,
            isBlockGuardActive = false,
            lastBlockGuardUpdateAt = 0,
            frozenSightUntil = 0,
            frozenSightEye = nil,
            frozenSightPos = nil,
            frozenSightDir = nil,
        },
        seikret = {
            jumpAttackUntil = 0,
            dismountContextUntil = 0,
            jumpWindowDuration = 1.0,
            lastUnarmedCallFocusDropAt = 0,
            unarmedCallAttemptUntil = 0,
            unarmedCallPrepareSeen = false,
            unarmedCallEnterSeen = false,
            unarmedCallSuccessNudged = false,
            restoreFocusOnSuccessfulUnarmedCall = false,
            pendingSuccessInputCheck = nil,
            pendingSuccessCommandWork = nil,
            pendingSuccessAt = 0,
            pendingSuccessAttempts = 0,
            pendingRideJudge = nil,
            pendingRideJudgeCommandWork = nil,
            pendingRideJudgeOptionArg = nil,
            pendingRideJudgeAt = 0,
            pendingRideJudgeAttempts = 0,
            pendingSubActionRequestAt = 0,
            pendingSubActionRequestAttempts = 0,
        },
        tooltip = {
            text = nil,
            position = nil,
        },
        hotkeys = {
            lastActionAt = 0,
        },
        scheduled = {},
    }
end

function M.reset_runtime(state)
    local fresh = M.new()

    state.caches = fresh.caches
    state.status = fresh.status
    state.pending = fresh.pending
    state.camera = fresh.camera
    state.seikret = fresh.seikret
    state.tooltip = fresh.tooltip
    state.hotkeys = fresh.hotkeys
    state.scheduled = fresh.scheduled
end

return M
