import asyncio
import websockets
import json
import os
import sys
import time

# Configuration
LILY_CORE_URL = os.environ.get("LILY_CORE_URL", "ws://localhost:8000")
SAMPLE_AUDIO_PATH = os.path.join(os.path.dirname(__file__), "samples", "hello_world.mp3")
CHUNK_SIZE = 32768  # 32KB chunks

def wait_for_services():
    """Wait for all required services to be healthy before running tests."""
    import requests
    
    services = [
        ("Echo", "http://echo:8000/health"),
        ("Lily-Core", "http://lily-core:8000/health"),
    ]
    
    max_retries = 30  # 30 retries * 2 seconds = 60 seconds max wait
    retry_interval = 2
    
    for service_name, health_url in services:
        print(f"Waiting for {service_name} to be ready...")
        for attempt in range(max_retries):
            try:
                resp = requests.get(health_url, timeout=5)
                if resp.status_code == 200:
                    print(f"✓ {service_name} is healthy: {resp.text}")
                    break
            except Exception as e:
                pass
            
            if attempt < max_retries - 1:
                print(f"  {service_name} not ready, retrying in {retry_interval}s... ({attempt + 1}/{max_retries})")
                time.sleep(retry_interval)
        else:
            print(f"✗ {service_name} failed to become healthy after {max_retries * retry_interval}s")
            sys.exit(1)
    
    print("All services are healthy!")

async def run_test():
    print(f"Testing Flow: TestScript -> {LILY_CORE_URL} -> Echo -> Response")
    print(f"Using Audio File: {SAMPLE_AUDIO_PATH}")
    
    if not os.path.exists(SAMPLE_AUDIO_PATH):
        print(f"Error: Audio file not found at {SAMPLE_AUDIO_PATH}")
        sys.exit(1)

    # Wait for services to be ready first
    import requests
    wait_for_services()

    try:
        # 1. Connect to Lily-Core
        async with websockets.connect(f"{LILY_CORE_URL}") as websocket:
            print("Connected to Lily-Core WebSocket")

            # 2. Transcribe sanity check
            print("Checking Echo Transcribe via HTTP...")
            files = {'file': ('test.mp3', open(SAMPLE_AUDIO_PATH, 'rb'), 'audio/mpeg')}
            resp = requests.post("http://echo:8000/v1/audio/transcriptions", files=files, timeout=30)
            print(f"Echo Transcribe Result: {resp.status_code} {resp.text}")
            
            # 3. WebSocket Check
            print("Checking Echo WebSocket directly...")
            try:
                async with websockets.connect("ws://echo:8000/ws/transcribe") as ws_echo:
                    print("Direct connection to Echo WebSocket SUCCEEDED")
                    await ws_echo.close()
            except Exception as e:
                print(f"Direct connection to Echo WebSocket FAILED: {e}")

            # Convert MP3 to PCM (16kHz, 16-bit, Mono)
            import subprocess
            print("Converting MP3 to PCM...")
            process = subprocess.Popen(
                ['ffmpeg', '-i', SAMPLE_AUDIO_PATH, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
            audio_data = process.stdout.read()
            
            total_size = len(audio_data)
            print(f"Sending {total_size} bytes of PCM audio...")

            # 4. Stream Audio in Chunks
            offset = 0
            while offset < total_size:
                chunk = audio_data[offset:offset + CHUNK_SIZE]
                await websocket.send(chunk)
                offset += len(chunk)
                await asyncio.sleep(0.01)

            # Send 3 seconds of silence to trigger VAD/Finalization
            silence = b'\x00' * 32000 * 3 
            await websocket.send(silence)
            print("Sent silence padding (3s).")

 
            
            print("Audio streaming complete. Waiting for transcription...")

            # 5. Listen for Transcription Response
            # We expect a JSON message with "transcription"
            start_time = time.time()
            timeout = 60  # Seconds to wait for transcription

            while time.time() - start_time < timeout:
                try:
                    message_str = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    print(f"Received: {message_str}")

                    # Check for transcription
                    # Format based on Lily-UI inspection: "transcription:{\"type\":\"...\",\"text\":\"...\"}"
                    if isinstance(message_str, str) and message_str.startswith("transcription:"):
                        json_payload = message_str.replace("transcription:", "", 1)
                        data = json.loads(json_payload)
                        
                        if data.get("type") == "final":
                            transcript_text = data.get("text", "").lower()
                            print(f"Final Transcription Received: '{transcript_text}'")
                            
                            # Assertion
                            if "hello world" in transcript_text or "hello" in transcript_text:
                                print("SUCCESS: Transcription matches expected content!")
                                return
                            else:
                                print(f"FAILURE: Unexpected transcript content. Expected 'hello world'.")
                                sys.exit(1)
                                
                except asyncio.TimeoutError:
                    print("Timeout waiting for message chunk...")
                    continue

            print("TIMEOUT: Did not receive final transcription in time.")
            sys.exit(1)

    except Exception as e:
        print(f"TEST ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(run_test())
