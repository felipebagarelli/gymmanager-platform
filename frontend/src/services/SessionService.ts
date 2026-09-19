import { apiFetch } from "./httpClient";
import type { WorkoutSession } from "../types/WorkoutSession";

export const getStudentSessions = async (studentId: number): Promise<WorkoutSession[]> => {
    const response = await apiFetch(`/api/v1/students/${studentId}/workout-sessions`);
    return response.ok ? await response.json() : [];
};
