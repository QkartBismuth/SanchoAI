enum ModelStatus {
  idle,
  loading,
  ready,
  generating,
  error,
}

class ModelState {
  final ModelStatus status;
  final String? errorMessage;
  final bool hasMultimodal;
  final double progress;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const ModelState({
    this.status = ModelStatus.idle,
    this.errorMessage,
    this.hasMultimodal = false,
    this.progress = 0.0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  ModelState copyWith({
    ModelStatus? status,
    String? errorMessage,
    bool? hasMultimodal,
    double? progress,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) => ModelState(
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    hasMultimodal: hasMultimodal ?? this.hasMultimodal,
    progress: progress ?? this.progress,
    promptTokens: promptTokens ?? this.promptTokens,
    completionTokens: completionTokens ?? this.completionTokens,
    totalTokens: totalTokens ?? this.totalTokens,
  );
}
