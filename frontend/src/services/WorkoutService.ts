import { apiFetch, readError } from "./httpClient";
import type { CreateWorkout } from "../types/CreateWorkout";
import type { Workout } from "../types/Workout";

const API_URL = "/workouts";


export const getAllWorkout = async (studentId: number): Promise<Workout[]> => {
    const response = await apiFetch(API_URL + "/student/" + studentId);
    return await response.json();
}

export const getWorkoutById = async (id: number): Promise<Workout> => {
    const response = await apiFetch(API_URL + "/" + id);
    return await response.json();
} 

export const unassignWorkout = async (workoutId: number, studentId: number) => {
    await apiFetch(API_URL + "/" + workoutId + "/assignments/" + studentId, {
        method: 'DELETE'});
}

export const addWorkout = async (createWorkout: CreateWorkout): Promise<Workout[]> => {
    await apiFetch(API_URL, {
        method: 'POST',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify(createWorkout)
    })
    return await getAllWorkout(createWorkout.studentId)
}

export const updateWorkoutById = async (id: number, name: string, studentId: number): Promise<Workout[]> => {
    await apiFetch(API_URL + "/" + id, {
        method: 'PUT',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify({ name })
    })
    return await getAllWorkout(studentId)
}

export const getMyWorkouts = async (): Promise<Workout[]> => {
    const response = await apiFetch(API_URL);
    return await response.json();
}

export const createTemplate = async (name: string): Promise<Workout[]> => {
    await apiFetch(API_URL, {
        method: 'POST',
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name })
    })
    return await getMyWorkouts()
}

export const renameTemplate = async (id: number, name: string): Promise<Workout[]> => {
    await apiFetch(API_URL + "/" + id, {
        method: 'PUT',
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name })
    })
    return await getMyWorkouts()
}

export const deleteTemplate = async (id: number): Promise<string | null> => {
    const response = await apiFetch(API_URL + "/" + id, { method: 'DELETE' })
    return response.ok ? null : await readError(response)
}

export const assignWorkout = async (workoutId: number, studentId: number): Promise<string | null> => {
    const response = await apiFetch(API_URL + "/" + workoutId + "/assignments", {
        method: 'POST',
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ studentId })
    })
    return response.ok ? null : await readError(response)
}
