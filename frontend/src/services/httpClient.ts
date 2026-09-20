// em producao o painel e servido em outro host que a API: defina VITE_API_URL no build
const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8080";

export const apiFetch = async (path: string, options: RequestInit = {}): Promise<Response> => {
    const token = localStorage.getItem("token");

    const headers = {
        ...(options.headers ?? {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
    };

    const response = await fetch(`${BASE_URL}${path}`, { ...options, headers });

    if (response.status === 401) {
        localStorage.removeItem("token");
        localStorage.removeItem("role");
        window.location.href = "/login";
    }

    return response;
};

export const readError = async (response: Response, fallback = "Erro inesperado."): Promise<string> => {
    try {
        const body = await response.json();
        return body.message ?? fallback;
    } catch {
        return fallback;
    }
};
