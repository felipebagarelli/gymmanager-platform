export interface LoginResponse {
    token: string;
    expiresInSeconds: number;
    role: string;
}
