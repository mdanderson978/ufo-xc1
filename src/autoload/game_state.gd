extends Node
## The single campaign-state object. Everything a save file contains lives
## here as plain serializable data: funds, bases, soldiers, research,
## calendar, UFOs, and other campaign systems as they land.

## True when a campaign is loaded/underway.
var campaign_active: bool = false

## Campaign data root. Kept as a Dictionary of plain types so SaveManager
## can round-trip it through JSON losslessly.
var campaign: Dictionary = {}

func new_campaign(seed_value: int = randi()) -> void:
	campaign = Jsonish.normalised(CampaignFactory.new_campaign(DataRegistry, seed_value))
	campaign_active = true
	EventBus.campaign_state_changed.emit()

func to_save_dict() -> Dictionary:
	return campaign.duplicate(true)

func from_save_dict(data: Dictionary) -> void:
	campaign = data.duplicate(true)
	campaign_active = true
	EventBus.campaign_state_changed.emit()
