import type { CreateWorkoutExercise } from "../types/CreateWorkoutExercise";
import type { WorkoutExercise } from "../types/WorkoutExercise";

const API_URL = ("http://localhost:8080/" + "workout-exercises" ) as string;


export const getAllWorkoutExercise = async (id: number): Promise<WorkoutExercise[]> => {
    const response = await fetch(API_URL + "/" + "workout/" + id);
    return await response.json();
}

export const getWorkoutExerciseById = async (id: number): Promise<WorkoutExercise> => {
    const response = await fetch(API_URL + "/" + id);
    return await response.json();
} 

export const deleteWorkoutExerciseById = async (id: number) => {
    await fetch(API_URL + "/" + id,{
        method: 'DELETE'});
}

export const addWorkoutExercise = async (createWorkoutExercise: CreateWorkoutExercise): Promise<WorkoutExercise[]> => {
    await fetch(API_URL, {
        method: 'POST',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify(createWorkoutExercise)
    })
    return await getAllWorkoutExercise(createWorkoutExercise.workoutId)
}

export const updateWorkoutExerciseById = async (workoutExercise: WorkoutExercise): Promise<WorkoutExercise[]> => {
    await fetch(API_URL + "/" + workoutExercise.id, {
        method: 'PUT',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify(workoutExercise)
    })
    return await getAllWorkoutExercise(workoutExercise.workoutId)
}