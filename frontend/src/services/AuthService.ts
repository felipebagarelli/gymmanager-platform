import { apiFetch } from "./httpClient";
import type { LoginResponse } from "../types/LoginResponse";

export const login = async (email: string, password: string): Promise<LoginResponse> => {
    const response = await apiFetch("/api/v1/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
        throw new Error("E-mail ou senha inválidos.");
    }

    const data: LoginResponse = await response.json();
    localStorage.setItem("token", data.token);
    localStorage.setItem("role", data.role);

    if (data.role === "TRAINER") {
        const meResponse = await apiFetch("/api/v1/trainers/me");
        if (meResponse.ok) {
            const me = await meResponse.json();
            localStorage.setItem("trainerId", String(me.id));
        }
    }

    return data;
};

export const logout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("role");
    localStorage.removeItem("trainerId");
};

export const isAuthenticated = (): boolean => {
    return localStorage.getItem("token") !== null;
};

export const getRole = (): string | null => localStorage.getItem("role");

export const getTrainerId = (): number | null => {
    const value = localStorage.getItem("trainerId");
    return value ? Number(value) : null;
};
