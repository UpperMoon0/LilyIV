# Audio Chat Feature - High-Level Design Document

## Overview

This document outlines the high-level design for the audio chat feature in Lily UI, which enables users to have voice conversations with the AI assistant. The feature includes both speech-to-text (STT) for user input and text-to-speech (TTS) for assistant responses.

## System Architecture

The audio chat feature is built on a distributed microservices architecture with the following components:

### Core Components

1.  **Lily-UI (Frontend)**
    *   React-based desktop application using the Tauri framework.
    *   Handles user interface and audio playback.
    *   Communicates with Lily-Core via Tauri commands and WebSocket for real-time data transfer.
    *   Receives audio activity detection events from the Rust backend for UI feedback.

2.  **Lily-Core (Backend)**
    *   A C++ application that orchestrates the conversation flow.
    *   Manages WebSocket connections with clients, handling both text and binary data.
    *   Routes messages between services, including forwarding audio data to Echo and receiving transcriptions.
    *   Handles the conversation memory and the agent loop.

3.  **Echo (Speech-to-Text Service)**
    *   A Python service using OpenAI Whisper for speech recognition.
    *   Provides both HTTP and WebSocket APIs for audio transcription.
    *   Supports real-time streaming transcription, allowing for immediate processing of audio chunks.

4.  **TTS-Provider (Text-to-Speech Service)**
    *   A Python service providing multiple TTS engines (e.g., Edge TTS, Zonos).
    *   WebSocket-based API for real-time audio generation.
    *   Supports multiple voices and languages.

### Communication Flow

The communication flow for the audio chat feature is as follows:

```
User → Lily-UI → WebSocket → Lily-Core → Echo (STT) → Lily-Core → Agent Loop → Lily-Core → TTS-Provider → Lily-Core → WebSocket → Lily-UI → User
```

## Feature Components

### 1. Audio Input (Speech-to-Text)

#### User Interface

*   A microphone button in the chat interface to toggle audio input.
*   An audio activity indicator that shows when the user is speaking.
*   A conversation mode toggle for continuous voice interaction.

#### Technical Implementation

*   **Audio Capture**: Audio is captured using CPAL (Cross-Platform Audio Library) in the Rust backend for low-latency, cross-platform microphone access.
*   **Real-time Streaming**: Audio data is processed in real-time and streamed to `Lily-Core` via WebSocket for forwarding to the `Echo` service.
*   **Activity Detection**: RMS (Root Mean Square) level calculation is performed in the Rust backend to detect voice activity, with events sent to the UI for visual feedback.
*   **Backend Forwarding**: `Lily-Core` receives the binary audio data and forwards it to the `Echo` service's `/ws/transcribe/{client_id}` WebSocket endpoint.
*   **Transcription**: The `Echo` service uses the Whisper model for real-time transcription and sends the transcribed text back to `Lily-Core`, including the `client_id` for proper routing.
*   **UI Update**: `Lily-Core` forwards the transcription to the corresponding `Lily-UI` client, which then populates the message bar.

### 2. Audio Output (Text-to-Speech)

#### User Interface

*   Automatic playback of the assistant's responses as audio.
*   Visual indicators when audio is playing.
*   A TTS settings panel for voice customization.

#### Technical Implementation

*   **TTS Request**: When TTS is enabled, `Lily-Core` sends text responses to the `TTS-Provider` via a WebSocket connection.
*   **Audio Generation**: The `TTS-Provider` generates audio using the selected engine and streams it back to `Lily-Core` in chunks.
*   **Frontend Streaming**: `Lily-Core` forwards the audio data to `Lily-UI` through the main WebSocket connection.
*   **Playback**: `Lily-UI` receives the binary audio data, creates a `Blob`, and plays it using the HTML5 `Audio` API.

### 3. Conversation Mode

#### User Interface

*   A toggle button to enable or disable the continuous conversation mode.
*   Visual feedback when in conversation mode.
*   Audio activity detection to automatically start and stop recording.
*   Live transcription display showing interim results as the user speaks.

#### Technical Implementation

*   **Continuous Capture**: CPAL continuously captures audio while in conversation mode.
*   **Real-time Analysis**: RMS level calculation in the Rust backend provides real-time audio activity detection, with visual feedback sent to the UI.
*   **Two-Stage Silence Detection**: The `Echo` service implements intelligent silence detection with two thresholds:
    *   **Short Pause (0.7s)**: Triggers interim transcription for live feedback in the UI
    *   **Long Pause (1.5s)**: Triggers final transcription and sends the complete message to the agent loop
*   **Streaming Transcription**: Audio chunks are continuously streamed to the `Echo` service for transcription, allowing for a more natural, hands-free conversation.
*   **Context Management**: The agent loop maintains the conversation's context, ensuring that the back-and-forth dialogue is coherent and context-aware.

### 4. Silence Detection Mechanism

#### Overview

The audio chat feature uses a sophisticated two-stage silence detection system to determine when a user has finished speaking. This prevents premature cut-offs during natural speech patterns like pauses and stutters while still providing responsive conversation flow.

```
User Speaking → Short Pause (0.7s) → Interim Transcription → Long Pause (1.5s) → Final Transcription → Agent Processing
     ↓              ↓                        ↓                        ↓                        ↓
  Audio Input    UI Update               Live Display            Message Sent            Response Generated
```

#### Technical Implementation

*   **RMS Level Monitoring**: Each audio chunk is analyzed for RMS (Root Mean Square) level to detect silence vs. speech.
*   **Silence Threshold**: Audio below 0.01 RMS is considered silence.
*   **Two-Stage Detection**:
    *   **Interim Transcription**: After 0.7 seconds of silence, sends interim transcription to UI for live feedback.
    *   **Final Transcription**: After 1.5 seconds of silence, sends final transcription to agent loop for processing.
*   **Configurable Parameters**: Silence durations and thresholds can be adjusted via environment variables.
*   **State Management**: Tracks silence start time and prevents duplicate interim transcriptions.

## Data Flow

### Audio Input Flow

1.  **User Action**: The user clicks the microphone button or activates conversation mode in `Lily-UI`.
2.  **Microphone Access**: The Rust backend requests microphone access using CPAL for cross-platform audio input.
3.  **Audio Capture**: Audio is captured continuously using CPAL in the Rust backend, with real-time RMS level calculation for activity detection.
4.  **WebSocket Streaming**: Audio data is streamed to `Lily-Core` via WebSocket for forwarding to the `Echo` service.
5.  **Backend Forwarding**: `Lily-Core` receives the audio data and forwards it to the `Echo` service's `/ws/transcribe` endpoint.
6.  **Transcription**: The `Echo` service uses Whisper to transcribe the audio and sends the text back to `Lily-Core`.
7.  **Agent Processing**: The transcribed text is processed by the agent loop to generate a response.
8.  **UI Update**: The final response is sent back to the UI.

### Audio Output Flow

1.  **Agent Response**: The assistant's response is generated by the agent loop.
2.  **TTS Request**: If TTS is enabled, `Lily-Core` sends the response text to the `TTS-Provider` via WebSocket.
3.  **Audio Streaming**: The `TTS-Provider` generates the audio and streams it back to `Lily-Core` in chunks.
4.  **Frontend Forwarding**: `Lily-Core` forwards the audio data to `Lily-UI` via the main WebSocket connection.
5.  **Audio Playback**: `Lily-UI` receives the audio data, creates a `Blob`, and plays it using the HTML5 `Audio` API.

## Configuration Options

### TTS Settings
- Speaker selection (multiple voice options)
- Sample rate configuration
- Model selection (Edge TTS or Zonos)
- Language selection

### Audio Device Settings
- Input device selection (microphone)
- Output device selection (speakers/headphones)

### Silence Detection Settings
- Short pause duration (default: 0.7 seconds) - Controls interim transcription timing
- Long pause duration (default: 1.5 seconds) - Controls final transcription timing
- Silence threshold (default: 0.01 RMS) - Audio level below which is considered silence

## Error Handling

### Audio Input Errors
- Microphone access denied
- Audio capture failures
- Network issues during audio transmission
- Transcription service unavailable

### Audio Output Errors
- Audio playback failures
- TTS service connectivity issues
- Audio data corruption

## Performance Considerations

### Latency Optimization
- Audio chunking for real-time processing
- WebSocket connections for low-latency communication
- Asynchronous processing in backend services

### Resource Management
- Efficient audio encoding/decoding
- Connection pooling for service communication
- Memory management for audio buffers

## Security Considerations

### Data Privacy
- Audio data is processed locally when possible
- No audio data is stored permanently
- Secure WebSocket connections between services

### Access Control
- User authentication for WebSocket connections
- Service-to-service communication security

## Future Enhancements

### Planned Features
- Noise reduction and audio enhancement
- Multi-language support expansion
- Custom voice training capabilities
- Voice activity detection refinements (adaptive thresholds, environmental noise compensation)

### Technical Improvements
- Better integration with streaming APIs
- Enhanced error recovery mechanisms
- Improved audio quality options
- Advanced conversation context management

## Dependencies

### External Services
- Whisper model for speech recognition
- Edge TTS or Zonos for text-to-speech generation

### Libraries and Frameworks
- **Tauri**: For the desktop application framework.
- **React**: For building the user interface components.
- **WebSocket++**: For the C++ WebSocket implementation in `Lily-Core`.
- **FastAPI**: For the Python services in `Echo` and `TTS-Provider`.
- **Reqwest**: For making HTTP requests in the Tauri application.
- **Serde**: For serialization and deserialization in Rust.
- **CPAL**: For cross-platform audio capture and processing in the Rust backend.

## Testing Considerations

### Functional Testing
- Audio capture and playback verification
- Speech recognition accuracy testing
- TTS quality and performance testing
- Conversation flow validation

### Performance Testing
- Latency measurements for audio processing
- Resource usage monitoring
- Stress testing with multiple concurrent users

### Compatibility Testing
- Cross-platform audio device support
- Cross-platform audio device compatibility with CPAL
- Different audio format handling

## Deployment Considerations

### System Requirements
- Microphone for audio input
- Speakers or headphones for audio output
- Sufficient CPU/memory for real-time audio processing
- Network connectivity for service communication

### Scaling
- Horizontal scaling of Echo and TTS-Provider services
- Load balancing for Lily-Core instances
- CDN for audio assets if needed

## Monitoring and Logging

### Key Metrics
- Audio processing latency
- Transcription accuracy rates
- TTS generation times
- User engagement with audio features

### Logging
- Audio capture and processing events
- Service communication logs
- Error and exception tracking
- Performance metrics collection