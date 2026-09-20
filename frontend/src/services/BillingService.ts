import { apiFetch, readError } from "./httpClient";
import type { PayoutAccount, Plan, TrainerSubscription } from "../types/Billing";

type Result<T> = { data?: T; error?: string };

const json = { "Content-Type": "application/json" };

export const getPlans = async (): Promise<Plan[]> => {
    const response = await apiFetch("/api/v1/plans");
    return response.ok ? await response.json() : [];
};

export const savePlan = async (
    plan: { name: string; description: string; priceCents: number; active?: boolean },
    id?: number,
): Promise<Result<Plan>> => {
    const response = await apiFetch(id ? `/api/v1/plans/${id}` : "/api/v1/plans", {
        method: id ? "PUT" : "POST",
        headers: json,
        body: JSON.stringify(plan),
    });
    if (!response.ok) return { error: await readError(response, "Não foi possível salvar o plano.") };
    return { data: await response.json() };
};

export const getPayoutAccount = async (): Promise<PayoutAccount> => {
    const response = await apiFetch("/api/v1/billing/payout-account");
    return response.ok ? await response.json() : { connected: false, chargesEnabled: false };
};

export const startOnboarding = async (): Promise<Result<{ url: string }>> => {
    const response = await apiFetch("/api/v1/billing/payout-account/onboarding", { method: "POST" });
    if (!response.ok) return { error: await readError(response, "Não foi possível iniciar o cadastro.") };
    return { data: await response.json() };
};

export const getTrainerSubscriptions = async (): Promise<TrainerSubscription[]> => {
    const response = await apiFetch("/api/v1/billing/subscriptions");
    return response.ok ? await response.json() : [];
};

export const formatPrice = (cents: number) =>
    (cents / 100).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
