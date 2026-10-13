/// Every challenge a stage can run. Names are persisted in alarm JSON, so
/// never rename an existing value.
enum ChallengeId {
  orientationHopscotch,
  tiltMaze,
  brokenCalculator,
  stroopTap,
  lightsOn,
  walkSteps,
  photoMatch,
  nfcTag,
  barcode,

  /// Was 'charger' (plug in at another charger), replaced at the owner's
  /// request: saved 'charger' stages load as this (StageConfig.fromJson).
  batteryGuess,
  heartRate,
  compass,
  watchSwing,
  watchSteps,
  stairs,
}
