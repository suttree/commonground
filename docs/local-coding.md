# Local coding

Run `bin/ai` from this repository to open OpenCode. The default model is
`ollama/qwen3.5:9b-coding`, served on this Mac at `127.0.0.1:11434`.
Use `/models` inside OpenCode to select another installed model. Only the
Ollama provider is enabled for this project.

The coding model is an alias of `qwen3.5:9b` with a 65,536-token context and
an 8,192-token response limit. Temperature is 0.2 and the presence penalty is
zero to reduce variation in code edits. It shares the original model weights.
To recreate it on another machine:

```sh
ollama pull qwen3.5:9b
printf 'FROM qwen3.5:9b\nPARAMETER num_ctx 65536\nPARAMETER num_predict 8192\nPARAMETER temperature 0.2\nPARAMETER presence_penalty 0\n' > /tmp/qwen-coding.Modelfile
ollama create qwen3.5:9b-coding -f /tmp/qwen-coding.Modelfile
```

This Mac reuses Recall's Ollama installation and model store under
`~/src/recall/.local/`. The `ollama` command in `~/.local/bin` links to that
installation. Its existing service disables Ollama cloud inference.
If the service stops, start `~/src/recall/scripts/serve-ollama.sh` in another
terminal to keep using the same model store.

OpenRouter is not configured. Adding it later would send prompts and selected
project context to a hosted model provider and require an account and API key.

## Instructions for coding agents

Make focused changes and atomic Git commits. Read the relevant code before
editing it, and run checks appropriate to the change. Do not deploy or push
unless asked.

When writing prose, follow the unslop skill at
https://github.com/backnotprop/pstack/blob/main/skills/unslop/SKILL.md.
Use plain language, avoid inflated claims and unnecessary formatting, and
keep explanations specific to the work.
