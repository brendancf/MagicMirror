// API keys and secrets. Copy to keys.js and fill in.
// keys.js is gitignored and must not be committed.
module.exports = {
	AVIATIONSTACK_KEY: "",    // AviationStack API key for MMM-FlightStatus (used if FLIGHTAWARE_KEY not set)
	FLIGHTAWARE_KEY: "",      // FlightAware AeroAPI key for MMM-FlightStatus (preferred if available)
	NEXTDNS_KEY: "",          // NextDNS API key (kept for reference, no longer used by MMM-NextDNS)
	NOTION_TOKEN: "",         // Notion integration token for MMM-NextDNS state
	NOTION_NEXTDNS_DB: "",    // Notion database ID for NextDNS state
};
