import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Self-hosted OpenAI-compatible endpoint (vLLM, LM Studio, Ollama, RunPod, …).
// Set ORNITH_BASE_URL / ORNITH_API_KEY in your environment. Never hard-code the key here.
// (pi also interpolates "$ENV_VAR" inside apiKey at request time, hence the fallback below.)
const ENDPOINT = process.env.ORNITH_BASE_URL ?? "https://YOUR-ENDPOINT-8000.proxy.runpod.net/v1";
const API_KEY = process.env.ORNITH_API_KEY ?? "$ORNITH_API_KEY";

export default function ornithExtension(pi: ExtensionAPI) {
    pi.registerProvider("ornith", {
        name: "Ornith (self-hosted)",
        baseUrl: ENDPOINT,
        apiKey: API_KEY,
        api: "openai-completions",
        models: [
            {
                id: "Ornith-1.0-35B",
                name: "Ornith 1.0 35B MoE",
                reasoning: true,
                input: ["text"],
                cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
                contextWindow: 131072,
                maxTokens: 32768,
            },
        ],
    });
}
