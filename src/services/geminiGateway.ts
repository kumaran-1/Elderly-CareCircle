export interface AiGatewayResponse {
  text: string;
  provider: "local" | "gemini" | "remote";
}

export class GeminiGateway {
  constructor(
    private readonly endpoint?: string,
    private readonly apiKey?: string,
    private readonly model = "gemini-3-flash-preview"
  ) {}

  async generate(prompt: string): Promise<AiGatewayResponse> {
    if (!this.endpoint && !this.apiKey) {
      return {
        provider: "local",
        text: [
          "I can provide general wellness guidance only.",
          `You asked: ${prompt}`,
          "Please contact a clinician if symptoms are severe, persistent, or worsening."
        ].join(" ")
      };
    }

    const url = this.endpoint ?? `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${encodeURIComponent(this.apiKey!)}`;
    const body = this.endpoint
      ? { prompt }
      : { contents: [{ parts: [{ text: prompt }] }] };
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(this.endpoint && this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {})
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      throw new Error(`Gemini request failed with ${response.status}`);
    }

    const data = (await response.json()) as {
      text?: string;
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = data.text ?? data.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("") ?? "";
    return {
      provider: this.endpoint ? "remote" : "gemini",
      text
    };
  }
}
