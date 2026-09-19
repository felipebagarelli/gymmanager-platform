import { apiFetch } from "./httpClient";
import type { Exercises } from "../types/Exercises";
import type { CreateExercise } from "../types/CreateExercise";

const API_URL = "/exercises";

export const getExercises = async (): Promise<Exercises[]> => {
    const response = await apiFetch(API_URL);
    return await response.json();
};

export const addExercise = async (createExercise: CreateExercise): Promise<Exercises[]> => {
    await apiFetch(API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(createExercise),
    });
    return await getExercises();
};

export const deleteExerciseById = async (id: number): Promise<Exercises[]> => {
    await apiFetch(API_URL + "/" + id, {
        method: 'DELETE'});
        return await getExercises();
    };


export const getExerciseById = async (id: number): Promise<Exercises> => {
    const response = await apiFetch (API_URL + "/" + id);
    return await response.json();
};

export const updateExercise = async (exercise: Exercises): Promise<Exercises[]> => {
    await apiFetch(API_URL + "/" + exercise.id, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(exercise),
    });
    return await getExercises();
}
