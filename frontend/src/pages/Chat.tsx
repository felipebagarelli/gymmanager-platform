import { useCallback, useEffect, useRef, useState } from "react";
import { getConversations, getMessages, markConversationRead, sendMessage } from "../services/ChatService";
import type { ChatMessage, ConversationSummary } from "../types/Chat";
import PageHeader from "../components/ui/PageHeader";

const MESSAGES_POLL_MS = 3000;
const LIST_POLL_MS = 8000;

const formatTime = (value: string) => {
    const date = new Date(value);
    const sameDay = date.toDateString() === new Date().toDateString();
    return sameDay
        ? date.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
        : date.toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
};

const appendNew = (current: ChatMessage[], incoming: ChatMessage[]) => {
    const known = new Set(current.map((message) => message.id));
    const fresh = incoming.filter((message) => !known.has(message.id));
    return fresh.length === 0 ? current : [...current, ...fresh];
};

function Chat() {
    const [conversations, setConversations] = useState<ConversationSummary[]>([]);
    const [selectedId, setSelectedId] = useState<number | null>(null);
    const [messages, setMessages] = useState<ChatMessage[]>([]);
    const [text, setText] = useState("");
    const [error, setError] = useState<string | null>(null);
    const [sending, setSending] = useState(false);
    const lastIdRef = useRef(0);
    const bottomRef = useRef<HTMLDivElement | null>(null);

    const refreshConversations = useCallback(async () => {
        setConversations(await getConversations());
    }, []);

    useEffect(() => {
        const load = async () => setConversations(await getConversations());
        load();
        const timer = window.setInterval(load, LIST_POLL_MS);
        return () => window.clearInterval(timer);
    }, []);

    // abre a conversa: carrega as mais recentes e marca como lida
    useEffect(() => {
        if (selectedId === null) return;
        let active = true;

        const open = async () => {
            const initial = await getMessages(selectedId);
            if (!active) return;
            lastIdRef.current = initial.length ? initial[initial.length - 1].id : 0;
            setMessages(initial);
            setError(null);
            await markConversationRead(selectedId);
            if (active) await refreshConversations();
        };
        open();

        // polling: so o que chegou depois da ultima mensagem conhecida
        const timer = window.setInterval(async () => {
            const incoming = await getMessages(selectedId, lastIdRef.current);
            if (!active || incoming.length === 0) return;
            lastIdRef.current = incoming[incoming.length - 1].id;
            setMessages((current) => appendNew(current, incoming));
            if (incoming.some((message) => message.senderRole === "STUDENT")) {
                await markConversationRead(selectedId);
                if (active) await refreshConversations();
            }
        }, MESSAGES_POLL_MS);

        return () => {
            active = false;
            window.clearInterval(timer);
        };
    }, [selectedId, refreshConversations]);

    useEffect(() => {
        bottomRef.current?.scrollIntoView?.({ block: "end" });
    }, [messages, selectedId]);

    const selected = conversations.find((conversation) => conversation.id === selectedId) ?? null;

    const handleSend = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const body = text.trim();
        if (!body || selectedId === null || sending) return;

        setSending(true);
        setError(null);
        const result = await sendMessage(selectedId, body);
        setSending(false);

        if (result.error) {
            setError(result.error);
            await refreshConversations();
            return;
        }
        const sent = result.message!;
        lastIdRef.current = Math.max(lastIdRef.current, sent.id);
        setMessages((current) => appendNew(current, [sent]));
        setText("");
        await refreshConversations();
    };

    return (
        <>
            <PageHeader title="Mensagens" description="Converse com seus alunos" />

            <div className="chat-layout">
                <aside className="chat-list" aria-label="Conversas">
                    {conversations.length === 0 && <p className="muted chat-empty">Nenhum aluno vinculado ainda.</p>}
                    {conversations.map((conversation) => (
                        <button
                            key={conversation.id}
                            type="button"
                            className={`chat-item${conversation.id === selectedId ? " active" : ""}`}
                            onClick={() => setSelectedId(conversation.id)}
                        >
                            <span className="chat-item-top">
                                <strong>{conversation.studentName}</strong>
                                {conversation.unreadCount > 0 && (
                                    <span className="chat-badge" aria-label={`${conversation.unreadCount} não lidas`}>
                                        {conversation.unreadCount}
                                    </span>
                                )}
                            </span>
                            <span className="chat-item-preview muted">
                                {conversation.lastMessage
                                    ? `${conversation.lastMessage.senderRole === "TRAINER" ? "Você: " : ""}${conversation.lastMessage.body}`
                                    : "Sem mensagens"}
                            </span>
                        </button>
                    ))}
                </aside>

                <section className="chat-thread" aria-label="Conversa">
                    {selected === null ? (
                        <p className="muted chat-empty">Selecione uma conversa.</p>
                    ) : (
                        <>
                            <header className="chat-thread-header">
                                <strong>{selected.studentName}</strong>
                            </header>

                            <div className="chat-messages">
                                {messages.length === 0 && <p className="muted chat-empty">Nenhuma mensagem ainda.</p>}
                                {messages.map((message) => (
                                    <div
                                        key={message.id}
                                        className={`bubble ${message.senderRole === "TRAINER" ? "mine" : "theirs"}`}
                                    >
                                        <span className="bubble-body">{message.body}</span>
                                        <span className="bubble-time">{formatTime(message.createdAt)}</span>
                                    </div>
                                ))}
                                <div ref={bottomRef} />
                            </div>

                            {error && <p className="form-error chat-error">{error}</p>}

                            {selected.canSend ? (
                                <form className="chat-form" onSubmit={handleSend}>
                                    <input
                                        type="text"
                                        name="message"
                                        value={text}
                                        maxLength={2000}
                                        placeholder="Escreva uma mensagem"
                                        onChange={(event) => setText(event.target.value)}
                                        autoComplete="off"
                                    />
                                    <button type="submit" disabled={sending || text.trim() === ""}>
                                        Enviar
                                    </button>
                                </form>
                            ) : (
                                <p className="muted chat-closed">
                                    Conversa encerrada: só é possível ler o histórico (vínculo inativo ou aluno desativado).
                                </p>
                            )}
                        </>
                    )}
                </section>
            </div>
        </>
    );
}

export default Chat;
