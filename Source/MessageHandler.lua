local PRT = LibStub("AceAddon-3.0"):GetAddon("PhenomRaidTools")
local MessageHandler = {}


-------------------------------------------------------------------------------
-- Local Helper

MessageHandler.SendMessageToSlave = function(message)
    if PRT.db.profile.testMode then
        if UnitInRaid("player") then
            C_ChatInfo.SendAddonMessage("PRT_MSG", message, "RAID") 
        else
            C_ChatInfo.SendAddonMessage("PRT_MSG", message, "WHISPER", UnitName("player")) 
        end       
    else
        C_ChatInfo.SendAddonMessage("PRT_MSG", message, "RAID")    
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

        if message.withSound then 
            targetMessage.withSound = "t"
        else 
            targetMessage.withSound = "f"
        end
        
        local receiverMessage = nil

        if (UnitExists(targetMessage.target))
        or targetMessage.target == "ALL" 
        or targetMessage.target == "HEALER" 
        or targetMessage.target == "TANK" 
        or targetMessage.target == "DAMAGER" then     
            -- Send "normal" message       
            receiverMessage = MessageHandler.MessageToReceiverMessage(targetMessage)
        elseif targetMessage.target == "$target" then
            -- Set event target as message target
            targetMessage.target = message.eventTarget
            receiverMessage = MessageHandler.MessageToReceiverMessage(targetMessage)    
        end
        
        if receiverMessage then
            PRT.Debug("Sending new message", receiverMessage)
            MessageHandler.SendMessageToSlave(receiverMessage) 
        end
    end    
end


-------------------------------------------------------------------------------
-- Public API

PRT.ExecuteMessage = function(message)
    if message then
        MessageHandler.ExecuteMessageAction(message)    
    end
end