import type { CreateWorkout } from "../types/CreateWorkout";
import type { Workout } from "../types/Workout";

const API_URL = ("http://localhost:8080/" + "workouts" ) as string;


export const getAllWorkout = async (id: number): Promise<Workout[]> => {
    const response = await fetch(API_URL + "/member/" + id);
    return await response.json();
}

export const getWorkoutById = async (id: number): Promise<Workout> => {
    const response = await fetch(API_URL + "/" + id);
    return await response.json();
} 

export const deleteWorkoutById = async (id: number) => {
    await fetch(API_URL + "/" + id,{
        method: 'DELETE'});
}

export const addWorkout = async (createWorkout: CreateWorkout): Promise<Workout[]> => {
    await fetch(API_URL, {
        method: 'POST',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify(createWorkout)
    })
    return await getAllWorkout(createWorkout.memberId)
}

export const updateWorkoutById = async (workout: Workout): Promise<Workout[]> => {
    await fetch(API_URL + "/" + workout.id, {
        method: 'PUT',
        headers: {
            "Content-Type": "application/json",
        }, body: JSON.stringify(workout)
    })
    return await getAllWorkout(workout.id)
}