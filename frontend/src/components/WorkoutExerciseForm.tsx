import { getExercises } from "../services/ExerciseService";
import { addWorkoutExercise } from "../services/WorkoutExerciseService";
import type { WorkoutExercise } from "../types/WorkoutExercise"
import {useEffect, useState} from "react"
import type {Exercises} from "../types/Exercises";
import WorkoutExerciseFields from "./WorkoutExerciseFields";
import { optionalNumber, optionalText } from "./workoutExerciseFormUtils";


type WorkoutExerciseFormProps = {
    onSuccess: (workoutExercise: WorkoutExercise[]) => void;
    workoutId: number;
}
function WorkoutExerciseForm({onSuccess, workoutId }:WorkoutExerciseFormProps) {
    const [exercises, setExercises] = useState<Exercises[]>([]);

    useEffect(()=>{
        getExercises().then((data)=>{
        setExercises(data);
        });
    },[])

    const handleSubmit = async(event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);

        onSuccess(await addWorkoutExercise({
            workoutId,
            exerciseId: Number(formData.get("exerciseId")),
            sets: Number(formData.get("sets")),
            reps: Number(formData.get("reps")),
            position: optionalNumber(formData.get("position")),
            restSeconds: optionalNumber(formData.get("restSeconds")),
            targetLoad: optionalNumber(formData.get("targetLoad")),
            notes: optionalText(formData.get("notes")),
        }))
    }

    return (
        <form onSubmit={handleSubmit}>
            <h2>Adicionar exercicio</h2>

            <WorkoutExerciseFields exercises={exercises} />

            <button type="submit" >
                Adicionar
            </button>
        </form>
    )
}
export default WorkoutExerciseForm;
