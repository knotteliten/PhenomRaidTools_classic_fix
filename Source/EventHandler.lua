local PRT = LibStub("AceAddon-3.0"):GetAddon("PhenomRaidTools")

local AceTimer = LibStub("AceTimer-3.0")


-------------------------------------------------------------------------------
-- Local Helper

local essentialEvents = {
	"PLAYER_REGEN_DISABLED", 
	"PLAYER_REGEN_ENABLED",
	"ENCOUNTER_START",
	"ENCOUNTER_END",
	"PLAYER_ENTERING_WORLD"
}


-------------------------------------------------------------------------------
-- Public API

PRT.RegisterEssentialEvents = function()
	for i, event in ipairs(essentialEvents) do
		PRT:RegisterEvent(event)
	end
end

PRT.UnregisterEssentialEvents = function()
	for i, event in ipairs(essentialEvents) do
		PRT:UnregisterEvent(event)
	end
end

function PRT:PLAYER_ENTERING_WORLD(event)
	AceTimer:ScheduleTimer(
		function()
			local name, type, _, difficulty = GetInstanceInfo()

			PRT.Debug("Zone entered.")
			
			if type == "party" then
				PRT.Debug("Player entered dungeon - checking difficulty")
				PRT.Debug("Current difficulty is", difficulty)
				
				if self.db.profile.enabledDifficulties["dungeon"][difficulty] then
					PRT.Debug("Enabling PhenomRaidTools for", name, "on difficulty", difficulty)
					PRT.enabled = true
				else
					PRT.Debug("Difficulty not configured. PhenomRaidTools disabled.")
					PRT.enabled = false
				end
			elseif type == "raid" then
				PRT.Debug("Player entered raid - checking difficulty")
				PRT.Debug("Current difficulty is"..difficulty)
				
				if self.db.profile.enabledDifficulties["dungeon"][difficulty] then
					PRT.Debug("Enabling PhenomRaidTools for", name, "on difficulty", difficulty)
					PRT.enabled = true
				else
					PRT.Debug("Difficulty not configured. PhenomRaidTools disabled.")
					PRT.enabled = false
				end
			elseif type == "none" then
				PRT.Debug("Player is not in a raid nor in a dungeon. PhenomRaidTools disabled.")
			end
		end,
		2
	)	
end

function PRT:ENCOUNTER_START(event, encounterID, encounterName)	
	if PRT.enabled then
		PRT.Debug("Encounter started - ", encounterID, encounterName)

		if not self.db.profile.testMode then
			local _, encounter = PRT.FilterEncounterTable(self.db.profile.encounters, encounterID)

			if encounter then
				if encounter.enabled then
					self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
					PRT.currentEncounter = {}
					PRT.currentEncounter.inFight = true
							
					PRT.currentEncounter.encounter = PRT.CopyTable(encounter)
				else
					PRT.Debug("Found encounter but it is disabled. Skipping encounter.")
				end
			end
		end

		PRT:COMBAT_LOG_EVENT_UNFILTERED(event)
	end
end

function PRT:ENCOUNTER_END(event)	
	if PRT.enabled then
		PRT.Debug("Encounter ended.")	
		PRT:COMBAT_LOG_EVENT_UNFILTERED(event)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

		if PRT.currentEncounter then
			PRT.currentEncounter.inFight = false
		end	
	end
end

function PRT:PLAYER_REGEN_DISABLED(event)	
	PRT.Debug("Combat started.")
	
	if self.db.profile.testMode then
		local _, encounter = PRT.FilterEncounterTable(self.db.profile.encounters, self.db.profile.testEncounterID)

		if encounter then
			if encounter.enabled then
				self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				PRT.currentEncounter = {}
				PRT.currentEncounter.inFight = true

				PRT.currentEncounter.encounter = PRT.CopyTable(encounter)		
			else
				PRT.Debug("Found encounter but it is disabled. Skipping encounter.")
			end
		end
	end	

	PRT:COMBAT_LOG_EVENT_UNFILTERED(event)
end

function PRT:PLAYER_REGEN_ENABLED(event)
	PRT.Debug("Combat stopped. Resetting encounter.")

	if PRT.enabled then		
		PRT:COMBAT_LOG_EVENT_UNFILTERED(event)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
	
	if PRT.currentEncounter then
		PRT.currentEncounter.inFight = false
	end
end

function PRT:COMBAT_LOG_EVENT_UNFILTERED(event)
	if PRT.currentEncounter then
		local timestamp, combatEvent, _, sourceGUID, sourceName, _, _, targetGUID, targetName, _, _, eventSpellID,_,_, eventExtraSpellID = CombatLogGetCurrentEventInfo()
		
		if PRT.currentEncounter.inFight then
			if PRT.currentEncounter.encounter then
				local timers = PRT.currentEncounter.encounter.Timers
				local rotations = PRT.currentEncounter.encounter.Rotations
				local healthPercentages = PRT.currentEncounter.encounter.HealthPercentages
				local powerPercentages = PRT.currentEncounter.encounter.PowerPercentages

				-- Checking Timer activation
				if timers then
					PRT.CheckTimerStartConditions(timers, event, combatEvent, eventSpellID, targetGUID, sourceGUID)
					PRT.CheckTimerStopConditions(timers, event, combatEvent, eventSpellID, targetGUID, sourceGUID)
					PRT.CheckTimerTimings(timers)
				end

				-- Checking Rotation activation
				if rotations then
					PRT.CheckRotationTriggerCondition(rotations, event, combatEvent, eventSpellID, targetGUID, targetName, sourceGUID, sourceName)
				end

				-- Checking Health Percentage activation
				if healthPercentages then
					PRT.CheckUnitHealthPercentages(healthPercentages)
				end

				-- Checking Resource Percentage activation
				if powerPercentages then
					PRT.CheckUnitPowerPercentages(powerPercentages)
				end

				-- Process Message Queue after activations
				if timers or rotations or healthPercentages or powerPercentages then
					PRT.ProcessMessageQueue()
				end
			end
		end
	end
end