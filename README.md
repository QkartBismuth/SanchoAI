# Sancho.AI

A local AI chatbot application for Android built with Flutter. Runs GGUF-compatible AI models directly on your device.

## Features

- **Local AI Model Execution** - Run GGUF-compatible language models (Llama, Mistral, Qwen, etc.) directly on Android
- **Chat Interface** - Clean and intuitive chat UI with markdown support
- **Model Management** - Easy model selection and loading from device storage
- **Customizable Generation Settings** - Temperature, max tokens, repeat penalty, context window, top P, top K, repeat last N
- **AI Personality** - Customize AI behavior with contextual instructions (formerly System Prompt)
- **Auto-Detect Template** - Automatically detect chat template from model filename
- **Chat Templates** - Support for ChatML, Llama-2, Alpaca, Vicuna, Phi, Gemma, Zephyr with auto-detection
- **Universal Template** - No formatting template for models that don't fit existing templates
- **Token Display** - Real-time display of prompt tokens, completion tokens, and remaining context
- **Stop Generation** - Ability to stop response generation mid-stream
- **Context Reset** - Automatic context reset when switching between chats
- **Import/Export Settings** - Save and load settings in TOON format with custom filename
- **Share Settings** - Share settings via other apps (social media, messaging, etc.)
- **Detailed Logging** - Comprehensive logging of model settings, generation parameters, and chat messages
- **View/Clear Logs** - View and clear application logs
- **Share Logs** - Share logs via other apps for debugging
- **Conversation Management** - Create, rename, and delete chat conversations
- **Continue Generation** - Continue generating response by appending to the last AI message
- **Reset Settings** - One-click reset of all generation parameters to defaults
- **Built-in Help** - Info page explaining each generation parameter with recommendations
- **Real-time Status** - Visual indicator showing model loading and generation status
- **Material You (Material Design 3)** - Modern UI with dynamic color theming from Android wallpaper
- **Dynamic Typography** - Noto Sans variable font family
- **Smooth Scrolling** - Bounce physics with overscroll glow indicator

## Requirements

- Android device with Android 8.0 (API 26) or higher
- GGUF format AI model file (.gguf)

## Installation

1. Download the latest APK from the Releases section
2. Install the APK on your Android device
3. Go to Settings and select your AI model file
4. Wait for the model to load
5. Start chatting!

## Model Setup

1. Download a GGUF-compatible model (e.g., from Hugging Face)
2. Transfer the model file to your Android device
3. Open the app → Settings → Select Model
4. Choose your model file and wait for loading to complete

Recommended models:
- Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
- llama-3.2-1b-instruct-q4_k_m.gguf
- mistral-7b-instruct-v0.2-q4_k_m.gguf

## Generation Settings

Configure generation parameters in Settings:

| Parameter | Range | Description |
|-----------|-------|-------------|
| **Temperature** | 0.1-2.0 | Controls randomness (lower = more focused) |
| **Max Tokens** | 64-4096 | Maximum response length |
| **Repeat Penalty** | 1.0-2.0 | Prevents repetitive responses and digital hallucinations |
| **Context Window** | 512-8192 | Conversation history size |
| **Top P** | 0.0-1.0 | Nucleus sampling threshold |
| **Top K** | 1-100 | Number of top tokens to consider |
| **Repeat Last N** | 0-128 | Recent tokens to check for repetition |

- **Reset** button to restore all settings to defaults
- **Info icon** provides detailed explanations of each parameter
- Optimized defaults to reduce digital hallucinations

## AI Personality

Customize the AI's personality and behavior (formerly System Prompt). Default: "You are a helpful AI assistant."

Example prompts:
- "You are a helpful AI assistant."
- "You are a Python programming expert. Provide clear, concise code examples."
- "You are a creative story writer. Write engaging narratives."

## Chat Templates

The app supports multiple chat templates for different model architectures:

| Template | Description |
|----------|-------------|
| **None (Universal)** | Simple format without special tokens - for generic models |
| **ChatML** | Default template for modern models (Qwen, Mistral, etc.) |
| **Llama-2** | Meta's Llama 2 instruction format |
| **Alpaca** | Stanford Alpaca instruction format |
| **Vicuna** | Vicuna conversation format |
| **Phi** | Microsoft's Phi model format |
| **Gemma** | Google's Gemma model format |
| **Zephyr** | Hugging Face Zephyr format |

Enable **Auto-Detection** to automatically detect the appropriate template based on the model filename (e.g., "llama-2" in filename → Llama-2 template).

## Token Display

During generation, the app displays:
- **Prompt** - Number of tokens in the input
- **Completion** - Number of tokens generated
- **Remaining** - Available context space (turns red when low)

## Stop Generation

While the AI is generating a response, tap the red stop button to:
- Cancel the current generation
- Save the partially generated response to the chat

## Context Reset

When switching between chats, the model context is automatically reset to ensure each conversation starts fresh without carrying over context from other chats.

## Import / Export Settings

Export and import your generation settings in TOON format:
- **Export Settings** - Save to Downloads folder or share via other apps
- **Import Settings** - Load settings from a .toon file

Settings include: AI Personality (System Prompt), Temperature, Max Tokens, Context Window, Repeat Penalty, Top P, Top K, Repeat Last N, Chat Template, Auto-Detection.

## Logs

The app includes comprehensive logging:
- **View Logs** - View all application logs in a scrollable dialog
- **Share Logs** - Share logs via other apps for debugging/support
- **Clear Logs** - Clear all logs to start fresh

Log includes: app startup, settings changes, model loading, generation parameters, chat messages, errors.

## Chat Management

- Swipe from left or tap menu icon to open chat list
- Create new chats with the + button
- **Rename** existing chats via the context menu (three dots)
- Delete chats via the context menu
- Each chat maintains its own conversation history

## Technical Details

- **Framework**: Flutter
- **State Management**: Riverpod
- **Model Runtime**: llama.cpp via llama_flutter_android
- **Storage**: SharedPreferences for settings and conversation history
- **Architecture**: Clean Architecture (Presentation / Domain / Data layers)
- **Logging**: Local file-based logging with detailed information

## Building from Source

```bash
# Clone the repository
git clone https://github.com/QkartBismuth/SanchoAI.git

# Navigate to project directory
cd SanchoAI

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## Screenshots

| Chat Screen | Settings |
|-------------|----------|
| Modern chat interface with status indicator | Model selection and configuration |

## License

MIT License

## Author

QkartBismuth
