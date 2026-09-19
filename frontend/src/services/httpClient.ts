const BASE_URL = "http://localhost:8080";

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
