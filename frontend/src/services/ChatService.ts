import { apiFetch, readError } from "./httpClient";
import type { ChatMessage, ConversationSummary } from "../types/Chat";

export const CHAT_READ_EVENT = "chat-read";

export const getConversations = async (): Promise<ConversationSummary[]> => {
    const response = await apiFetch("/api/v1/conversations");
    return response.ok ? await response.json() : [];
};

// sem `after`: as mais recentes; com `after`: apenas as posteriores (polling)
export const getMessages = async (conversationId: number, after?: number): Promise<ChatMessage[]> => {
    const query = after === undefined ? "" : `?after=${after}`;
    const response = await apiFetch(`/api/v1/conversations/${conversationId}/messages${query}`);
    return response.ok ? await response.json() : [];
};

export const sendMessage = async (
    conversationId: number,
    body: string,
): Promise<{ message?: ChatMessage; error?: string }> => {
    const response = await apiFetch(`/api/v1/conversations/${conversationId}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body }),
    });
    if (!response.ok) {
        return { error: await readError(response, "Não foi possível enviar a mensagem.") };
    }
    return { message: await response.json() };
};

export const markConversationRead = async (conversationId: number): Promise<void> => {
    await apiFetch(`/api/v1/conversations/${conversationId}/read`, { method: "POST" });
    window.dispatchEvent(new Event(CHAT_READ_EVENT));
};
