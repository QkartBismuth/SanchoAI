import 'package:flutter/material.dart';

class GenerationParamsInfoScreen extends StatelessWidget {
  const GenerationParamsInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generation Parameters'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Understanding AI Generation Parameters',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Learn how each parameter affects AI model behavior and output quality.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildParameterCard(
            context,
            'Temperature',
            'Controls randomness in text generation. Lower values produce more focused and deterministic outputs, while higher values increase creativity and variety.',
            '• 0.1-0.4: Focused, deterministic responses\n• 0.5-0.8: Balanced creativity\n• 0.9-2.0: Creative, varied outputs\n\nRecommended: 0.5-0.7 for general use.',
            Icons.thermostat_rounded,
          ),
          _buildParameterCard(
            context,
            'Max Tokens',
            'Maximum number of tokens (words or word parts) the AI can generate in a single response. Affects response length and memory usage.',
            '• 64-128: Very short responses\n• 256-512: Standard chat responses\n• 1024+: Long-form content\n\nRecommended: 256-512 for chat.',
            Icons.text_fields_rounded,
          ),
          _buildParameterCard(
            context,
            'Repeat Penalty',
            'Penalizes the model for repeating the same tokens. Higher values reduce repetition but may make responses less natural.',
            '• 1.0: No penalty\n• 1.1-1.2: Light penalty (recommended)\n• 1.5+: Strong penalty\n\nRecommended: 1.1-1.2 to prevent repetitive responses and digital hallucinations.',
            Icons.repeat_rounded,
          ),
          _buildParameterCard(
            context,
            'Context Window',
            'Number of previous tokens the model considers when generating a response. Larger windows provide more conversation history but use more memory.',
            '• 512-1024: Short conversations\n• 2048: Standard (recommended)\n• 4096-8192: Long conversations\n\nNote: Must be within model\'s supported context size.',
            Icons.memory_rounded,
          ),
          _buildParameterCard(
            context,
            'Top P (Nucleus Sampling)',
            'Controls vocabulary selection based on cumulative probability. Only tokens with combined probability above this threshold are considered.',
            '• 0.1-0.5: Very focused vocabulary\n• 0.7-0.9: Balanced (recommended)\n• 0.95-1.0: Maximum diversity\n\nNote: Use either Top P or Top K, not both.',
            Icons.filter_list_rounded,
          ),
          _buildParameterCard(
            context,
            'Top K',
            'Limits vocabulary to the top K most probable tokens. Lower values make outputs more predictable, higher values increase variety.',
            '• 1-10: Very focused\n• 20-40: Balanced (recommended)\n• 50-100: More diverse\n\nNote: Use either Top K or Top P, not both.',
            Icons.format_list_numbered_rounded,
          ),
          _buildParameterCard(
            context,
            'Repeat Last N',
            'Number of recent tokens to consider when applying repeat penalty. Affects how far back the model looks to detect and prevent repetition.',
            '• 0-16: Only recent tokens\n• 32-64: Recommended for conversation\n• 64-128: Longer context\n\nRecommended: 32-64 for chat.',
            Icons.history_rounded,
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reducing Digital Hallucinations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Digital hallucinations occur when the AI generates nonsensical or factually incorrect information. To reduce them:',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Increase Repeat Penalty (1.1-1.3)\n• Decrease Temperature (0.3-0.6)\n• Use lower Top K values (10-30)\n• Provide clear, specific prompts\n• Use accurate system prompts',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'For optimal chat performance, the app uses conservative defaults tuned to reduce hallucinations while maintaining response quality.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildParameterCard(
    BuildContext context,
    String title,
    String description,
    String recommendations,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Recommendations:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendations,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
