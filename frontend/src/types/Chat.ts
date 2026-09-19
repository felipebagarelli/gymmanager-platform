export type ChatSender = "TRAINER" | "STUDENT";

export interface ChatMessage {
    id: number;
    conversationId: number;
    senderRole: ChatSender;
    body: string;
    createdAt: string;
}

export interface ConversationSummary {
    id: number;
    studentId: number;
    studentName: string;
    trainerId: number;
    trainerName: string;
    lastMessage: ChatMessage | null;
    unreadCount: number;
    canSend: boolean;
}
