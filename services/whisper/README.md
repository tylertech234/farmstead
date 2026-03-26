# Whisper — speech-to-text for meeting minutes

This service runs OpenAI's Whisper model behind a REST API, allowing n8n to
transcribe meeting audio recordings into text for summarisation.

## Purpose in this stack

- **Meeting audio transcription** — upload a recording and get a text transcript
- **Pipeline input** — n8n sends audio to Whisper, then passes the transcript to Ollama for summarisation and formatting into meeting minutes

## Model selection

Set `WHISPER_MODEL` in `.env` based on your hardware:

| Model | Params | RAM | Speed | Best for |
|---|---|---|---|---|
| `tiny` | 39 M | ~1 GB | Fastest | Raspberry Pi / SBC |
| `base` | 74 M | ~1 GB | Fast | Laptop (no GPU) |
| `small` | 244 M | ~2 GB | Moderate | Laptop with GPU |
| `medium` | 769 M | ~5 GB | Slow | Desktop with GPU |

Default: `tiny` (SBC-friendly). Change in `.env` to match your hardware.

## API usage

The Whisper service exposes a Swagger UI at `http://whisper:9000/docs`.

### Transcribe an audio file

```bash
curl -X POST http://localhost:9000/asr \
  -F "audio_file=@meeting-2024-03-15.mp3" \
  -F "output=json"
```

### From n8n

Use an **HTTP Request** node:
- Method: `POST`
- URL: `http://whisper:9000/asr`
- Body: Form-Data with the audio file binary
- Parse response as JSON

> For full API documentation see the
> [whisper-asr-webservice docs](https://github.com/ahmetoner/whisper-asr-webservice).
