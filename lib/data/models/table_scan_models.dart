enum TableTagResolutionFailure {
  unknownTag,
  wrongEventOrUnbound,
  nonTableTag,
}

class TableTagResolutionException implements Exception {
  const TableTagResolutionException(this.failure);

  final TableTagResolutionFailure failure;

  String get message {
    return switch (failure) {
      TableTagResolutionFailure.unknownTag =>
        'Unknown table tag. Bind this tag to a table first.',
      TableTagResolutionFailure.wrongEventOrUnbound =>
        'This tag is not assigned to a table in this event.',
      TableTagResolutionFailure.nonTableTag => 'Expected a table tag.',
    };
  }

  @override
  String toString() => message;
}
