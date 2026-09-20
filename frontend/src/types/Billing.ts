export type Plan = {
    id: number;
    name: string;
    description: string | null;
    priceCents: number;
    active: boolean;
};

export type PayoutAccount = {
    connected: boolean;
    chargesEnabled: boolean;
};

export type SubscriptionStatus = "PENDING" | "ACTIVE" | "PAST_DUE" | "CANCELED";

export type TrainerSubscription = {
    id: number;
    status: SubscriptionStatus;
    planId: number;
    planName: string;
    priceCents: number;
    currentPeriodEnd: string | null;
    studentId: number;
    studentName: string;
};
