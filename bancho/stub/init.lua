--- Stub implementations for external dependencies.
---
--- Provides testable in-memory replacements for:
--- - bcrypt password hashing
--- - score crypto (Rijndael-256)
--- - database repos
--- - HTTP client
--- - geolocation
--- - performance calculator

return {
	BcryptHasher = require("bancho.stub.BcryptHasher"),
	Repo = require("bancho.stub.Repo"),
	HttpClient = require("bancho.stub.HttpClient"),
	GeoLocator = require("bancho.stub.GeoLocator"),
	PerformanceCalculator = require("bancho.stub.PerformanceCalculator"),
}
