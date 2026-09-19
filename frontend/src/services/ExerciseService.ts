import type { Exercises } from "../types/Exercises";
import type { CreateExercise } from "../types/CreateExercise";

const API_URL = "http://localhost:8080/exercises";

export const getExercises = async (): Promise<Exercises[]> => {
    const response = await fetch(API_URL);
    return await response.json();
};

export const addExercise = async (createExercise: CreateExercise): Promise<Exercises[]> => {
    await fetch(API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(createExercise),
    });
    return await getExercises();
};

export const deleteExerciseById = async (id: number): Promise<Exercises[]> => {
    await fetch(API_URL + "/" + id, {
        method: 'DELETE'});
        return await getExercises();
    };


export const getExerciseById = async (id: number): Promise<Exercises> => {
    const response = await fetch (API_URL + "/" + id);
    return await response.json();
};

export const updateExercise = async (exercise: Exercises): Promise<Exercises[]> => {
    await fetch(API_URL + "/" + exercise.id, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(exercise),
    });
    return await getExercises();
}