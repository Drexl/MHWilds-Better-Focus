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
            managedFocusSession = false,
            wasTargeting = nil,
            wasWeaponDrawn = nil,
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
            unarmedCallAttemptId = 0,
            unarmedCallAttemptUntil = 0,
            lastUnarmedCallNudgeAt = 0,
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
        binding = {
            dashCustomKey = false,
            seikretCustomKey = false,
        },
        hotkeys = {
            lastActionAt = 0,
        },
        scheduled = {},
    }
end

return M
