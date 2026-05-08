# Hatch Eval Tips

## Basic Eval Runs
From `~/Projects/jarvis/evals`:
- Base command: `uv run run.py --mode persistent-feather`
- `-j` controls parallelism (e.g., `-j 1` serial, `-j 3` concurrent)
- `--bundle ci:wearables` for the standard wearables bundle
- Specify individual cases by path, e.g. `cases/ping_pong`, `cases/math/add_01`

## Using Your Own Deployment
- Add `--repeat 2 --pass-if-any` to retry flaky cases
- Use `--bundle ci:audio-eval-cases-v2 --suite comms-cria-product-tests-audio.yaml` for custom bundle/suite

## Audio Evals
- Audio-specific cases live under `cases/comms/native/comms_audio_*`
- Generate test audio: `say -o ~/test/test.aiff "Hello, this is a test audio file"`
- Test with: `uv run --with anthropic python3 audio.py`

## PR-Scoped Runs
- Use `--bundle ci:audio-eval-cases-v2 --suite comms-cria-product-tests.yaml` for your PR bundle

## Quick Reference Commands
```sh
# basic wearables eval
uv run run.py --mode persistent-feather -j 1 --bundle ci:wearables cases/ping_pong

# your deployment with retries
uv run run.py --mode persistent-feather -j 3 --repeat 2 --pass-if-any --bundle ci:audio-eval-cases-v2 --suite comms-cria-product-tests-audio.yaml

# audio eval cases
uv run run.py --mode persistent-feather -j 1 --bundle ci:wearables cases/comms/native/comms_audio_call_single_match cases/comms/native/comms_audio_message_single_match cases/comms/native/comms_audio_call_ambiguous

# v2 bundle with high parallelism
uv run run.py --mode persistent-feather -j 9 --bundle ci:audio-eval-cases-v2 --suite <your-suite>.yaml
```
