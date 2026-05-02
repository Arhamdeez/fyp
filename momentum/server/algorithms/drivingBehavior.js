const detectHarshBraking = (speedReadings, timestamps, threshold = -8) => {
  let count = 0;
  for (let i = 1; i < speedReadings.length; i += 1) {
    const deltaSpeed = speedReadings[i] - speedReadings[i - 1];
    const deltaTime = (new Date(timestamps[i]) - new Date(timestamps[i - 1])) / 1000;
    if (deltaTime <= 0) continue;
    const deceleration = deltaSpeed / deltaTime;
    if (deceleration < threshold) count += 1;
  }
  return count;
};

const detectRapidAcceleration = (speedReadings, timestamps, threshold = 4) => {
  let count = 0;
  for (let i = 1; i < speedReadings.length; i += 1) {
    const deltaSpeed = speedReadings[i] - speedReadings[i - 1];
    const deltaTime = (new Date(timestamps[i]) - new Date(timestamps[i - 1])) / 1000;
    if (deltaTime <= 0) continue;
    const acceleration = deltaSpeed / deltaTime;
    if (acceleration > threshold) count += 1;
  }
  return count;
};

const detectOverspeeding = (speedReadings, speedLimit = 120) =>
  speedReadings.filter((speed) => speed > speedLimit).length;

const classifyDrivingScore = (score) => {
  if (score >= 90) return "Excellent";
  if (score >= 75) return "Good";
  if (score >= 50) return "Average";
  return "Poor";
};

const calculateDrivingScore = (harshBraking, rapidAccel, overspeeding) => {
  const baseScore = 100;
  const penalty = harshBraking * 5 + rapidAccel * 4 + overspeeding * 6;
  const score = Math.max(0, baseScore - penalty);
  return { score, classification: classifyDrivingScore(score) };
};

module.exports = {
  detectHarshBraking,
  detectRapidAcceleration,
  detectOverspeeding,
  calculateDrivingScore,
  classifyDrivingScore
};
