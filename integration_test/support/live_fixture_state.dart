class LiveFixtureState {
  LiveFixtureState({
    this.eventId,
    this.eventTitle,
  });

  String? eventId;
  String? eventTitle;
  final Set<String> normalizedTagUids = <String>{};
}
