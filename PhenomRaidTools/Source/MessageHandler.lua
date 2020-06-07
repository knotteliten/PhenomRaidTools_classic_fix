local PRT = LibStub("AceAddon-3.0"):GetAddon("PhenomRaidTools")

local AceComm = LibStub("AceComm-3.0")

local MessageHandler = {}

local validTargets = {    
    "ALL", 
    "HEALER",
    "TANK",
    "DAMAGER"
}

-------------------------------------------------------------------------------
-- Local Helper

MessageHandler.SendMessageToReceiver = function(message)
    if PRT.PlayerInParty() then
        C_ChatInfo.SendAddonMessage(PRT.db.profile.addonPrefixes.weakAuraMessage, message, "RAID")    
    else
        C_ChatInfo.SendAddonMessage(PRT.db.profile.addonPrefixes.weakAuraMessage, message, "WHISPER", UnitName("player"))         
    end
end

MessageHandler.MessageToReceiverMessage = function(message)
    local target = message.target or ""
    local spellID = message.spellID or ""
    local duration = message.duration or ""
    local withSound = message.withSound or ""
    local message = message.message or ""
    
    return target.."?"..spellID.."#"..duration.."&"..message.."~"..withSound
end

MessageHandler.ExecuteMessageAction = function(message)
    for i, target in ipairs(message.targets) do
        local targetMessage = PRT.CopyTable(message)
        targetMessage.target = strtrim(target, " ")
        targetMessage.message = PRT.ReplacePlayerNameTokens(targetMessage.message)

        -- Cleanup unused fields
        targetMessage.targets = nil                

        if targetMessage.target == "$target" then
            -- Set event target as message target
            targetMessage.target = message.eventTarget  
        elseif targetMessage.target == "$me" or string.match(targetMessage.target, "$tank") or string.match(targetMessage.target, "$heal") then      
            -- send message to token target  
            targetMessage.target = PRT.ReplacePlayerNameTokens(targetMessage.target)
        end
        
        if UnitExists(targetMessage.target) or tContains(validTargets, targetMessage.target) then
            if not PRT.db.profile.weakAuraMode then
                PRT.Debug("Sending new message to", targetMessage.target)
                targetMessage.sender = PRT.db.profile.myName
                AceComm:SendCommMessage(PRT.db.profile.addonPrefixes.addonMessage, PRT.TableToString(targetMessage), "WHISPER", UnitName("player")) 
            elseif PRT.db.profile.weakAuraMode then
                local weakAuraReceiverMessage = nil
                -- Determine if the message should play a sound on the receiver side
                if message.withSound then 
                    targetMessage.withSound = "t"
                else 
                    targetMessage.withSound = "f"
                end
                weakAuraReceiverMessage = MessageHandler.MessageToReceiverMessage(targetMessage) 
                PRT.Debug("Sending new weakaura message", weakAuraReceiverMessage)
                MessageHandler.SendMessageToReceiver(weakAuraReceiverMessage) 
            end
        else
            PRT.Error("Target", targetMessage.target, "does not exist. Skipping message.")
        end        
    end    
end

function PRT:OnAddonMessage(message)
    if not PRT.db.profile.weakAuraMode then
        local worked, messageTable = PRT.StringToTable(message)
        if PRT.db.profile.receiverMode then 
            if (messageTable.sender == PRT.db.profile.receiveMessagesFrom or 
                PRT.db.profile.receiveMessagesFrom == "$me" or
                PRT.db.profile.receiveMessagesFrom == nil or
                PRT.db.profile.receiveMessagesFrom == "") then
                PRT.ReceiverOverlay.AddMessage(messageTable)
            else
                PRT.Debug("We received a message from", PRT.HighlightString(messageTable.sender), "and only accept messages from", PRT.HighlightString(PRT.db.profile.receiveMessagesFrom), "therefore skipping the message.")
            end
        end
    end
end

function PRT:OnVersionRequest(message)
    local worked, messageTable = PRT.StringToTable(message)
    if messageTable.requestor then
        local response = {
            type = "response",
            name = strjoin("-", UnitFullName("player")),
            version = PRT.db.profile.version
        }
        PRT.PrintTable("", response)
        AceComm:SendCommMessage(PRT.db.profile.addonPrefixes.versionResponse, PRT.TableToString(response), "WHISPER", messageTable.requestor) 
    end
end

function PRT:OnVersionResponse(message)        
    local worked, messageTable = PRT.StringToTable(message)   
    PRT.db.profile.versionCheck[messageTable.name] = messageTable.version
end


-------------------------------------------------------------------------------
-- Public API

PRT.ExecuteMessage = function(message)
    if message then
        MessageHandler.ExecuteMessageAction(message)    
    end
end