import crypto from "crypto";
import type { Conversation, SystemStore } from "../domain/types";
import { GeminiGateway } from "./geminiGateway";
import { config } from "../config";

const emergencyPatterns = [
  /chest pain/i,
  /difficulty breathing/i,
  /shortness of breath/i,
  /severe bleeding/i,
  /unconscious/i,
  /stroke/i,
  /heart attack/i,
  /seizure/i,
  /cannot breathe/i,
  /collapse/i
];

export class AiService {
  private readonly gateway = new GeminiGateway(config.geminiEndpoint, config.geminiApiKey, config.geminiModel);

  constructor(private readonly store: SystemStore) {}

  async chat(userId: string, elderId: string | undefined, question: string): Promise<{ conversation: Conversation; disclaimer: string; provider: "local" | "gemini" | "remote" }> {
    const emergencyDetected = emergencyPatterns.some((pattern) => pattern.test(question));
    const gatewayResponse = emergencyDetected ? { provider: "local" as const, text: "" } : await this.gateway.generate(question);
    const answer = emergencyDetected
      ? [
          "This sounds urgent.",
          "Call emergency services or activate SOS immediately.",
          "If the person is not responding or breathing normally, seek urgent medical help right now.",
          "This guidance is general only and does not diagnose or replace professional care."
        ].join(" ")
      : gatewayResponse.text || [
          "I can offer general wellness guidance only.",
          "Please monitor symptoms, rest, hydrate, and contact a clinician if symptoms worsen or persist.",
          "This is not medical diagnosis or personalized treatment advice."
        ].join(" ");

    const conversation: Conversation = {
      id: crypto.randomUUID(),
      userId,
      elderId,
      question,
      answer,
      emergencyDetected,
      createdAt: new Date().toISOString()
    };

    this.store.conversations.push(conversation);
    return {
      conversation,
      disclaimer: "CareCircle AI provides general health guidance only and does not replace a licensed clinician.",
      provider: gatewayResponse.provider
    };
  }

  listConversationsForUser(userId: string): Conversation[] {
    return this.store.conversations.filter((conversation) => conversation.userId === userId);
  }
}
