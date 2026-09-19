import { useEffect, useState } from "react";
import { CHAT_READ_EVENT, getConversations } from "../services/ChatService";
import { isAuthenticated } from "../services/AuthService";

const POLL_MS = 10000;

/** Total de mensagens nao lidas do usuario logado (atualiza sozinho). */
export function useUnreadTotal(): number {
    const [total, setTotal] = useState(0);

    useEffect(() => {
        let active = true;

        const refresh = async () => {
            if (!isAuthenticated()) return;
            const conversations = await getConversations();
            if (active) setTotal(conversations.reduce((sum, c) => sum + c.unreadCount, 0));
        };

        refresh();
        const timer = window.setInterval(refresh, POLL_MS);
        window.addEventListener(CHAT_READ_EVENT, refresh);
        return () => {
            active = false;
            window.clearInterval(timer);
            window.removeEventListener(CHAT_READ_EVENT, refresh);
        };
    }, []);

    return total;
}
