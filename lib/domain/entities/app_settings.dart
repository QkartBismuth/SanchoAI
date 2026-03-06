class AppSettings {
  String modelPath;
  String mmprojPath;
  String systemPrompt;
  double temperature;
  int maxTokens;
  int contextWindow;
  double repeatPenalty;
  double topP;
  int topK;
  int repeatLastN;
  String theme;
  String language;
  String chatTemplate;
  bool autoDetectTemplate;

  AppSettings({
    this.modelPath = '',
    this.mmprojPath = '',
    this.systemPrompt = 'You are a helpful AI assistant.',
    this.temperature = 0.5,
    this.maxTokens = 256,
    this.contextWindow = 2048,
    this.repeatPenalty = 1.15,
    this.topP = 0.8,
    this.topK = 30,
    this.repeatLastN = 64,
    this.theme = 'system',
    this.language = 'en',
    this.chatTemplate = 'none',
    this.autoDetectTemplate = true,
  });

  Map<String, dynamic> toJson() => {
    'modelPath': modelPath,
    'mmprojPath': mmprojPath,
    'systemPrompt': systemPrompt,
    'temperature': temperature,
    'maxTokens': maxTokens,
    'contextWindow': contextWindow,
    'repeatPenalty': repeatPenalty,
    'topP': topP,
    'topK': topK,
    'repeatLastN': repeatLastN,
    'theme': theme,
    'language': language,
    'chatTemplate': chatTemplate,
    'autoDetectTemplate': autoDetectTemplate,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    modelPath: json['modelPath'] ?? '',
    mmprojPath: json['mmprojPath'] ?? '',
    systemPrompt: json['systemPrompt'] ?? 'You are a helpful AI assistant.',
    temperature: (json['temperature'] ?? 0.5).toDouble(),
    maxTokens: json['maxTokens'] ?? 256,
    contextWindow: json['contextWindow'] ?? 2048,
    repeatPenalty: (json['repeatPenalty'] ?? 1.1).toDouble(),
    topP: (json['topP'] ?? 0.8).toDouble(),
    topK: json['topK'] ?? 40,
    repeatLastN: json['repeatLastN'] ?? 64,
    theme: json['theme'] ?? 'system',
    language: json['language'] ?? 'en',
    chatTemplate: json['chatTemplate'] ?? 'none',
    autoDetectTemplate: json['autoDetectTemplate'] ?? true,
  );

  AppSettings copyWith({
    String? modelPath,
    String? mmprojPath,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    int? contextWindow,
    double? repeatPenalty,
    double? topP,
    int? topK,
    int? repeatLastN,
    String? theme,
    String? language,
    String? chatTemplate,
    bool? autoDetectTemplate,
  }) => AppSettings(
    modelPath: modelPath ?? this.modelPath,
    mmprojPath: mmprojPath ?? this.mmprojPath,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
    contextWindow: contextWindow ?? this.contextWindow,
    repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    topP: topP ?? this.topP,
    topK: topK ?? this.topK,
    repeatLastN: repeatLastN ?? this.repeatLastN,
    theme: theme ?? this.theme,
    language: language ?? this.language,
    chatTemplate: chatTemplate ?? this.chatTemplate,
    autoDetectTemplate: autoDetectTemplate ?? this.autoDetectTemplate,
  );
}
