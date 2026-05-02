const dtcDatabase = require("../utils/dtcDatabase");

const severityPriority = { High: 1, Medium: 2, Low: 3 };

const decodeErrorCodes = (errorCodesArray = []) =>
  errorCodesArray.map((code) => {
    const entry = dtcDatabase[code] || {
      description: "Unknown diagnostic code",
      severity: "Low",
      action: "Run detailed inspection with certified technician"
    };

    return {
      code,
      description: entry.description,
      severity: entry.severity,
      suggestedAction: entry.action
    };
  });

const generateMaintenanceRecommendations = (decodedCodes = []) =>
  decodedCodes
    .sort((a, b) => severityPriority[a.severity] - severityPriority[b.severity])
    .map((item) => ({
      ...item,
      urgency: item.severity === "High" ? "Immediate" : item.severity === "Medium" ? "Soon" : "Routine"
    }));

module.exports = { decodeErrorCodes, generateMaintenanceRecommendations };
