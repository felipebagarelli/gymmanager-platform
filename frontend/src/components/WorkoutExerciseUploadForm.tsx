import { getExercises } from "../services/ExerciseService";
import { updateWorkoutExerciseById } from "../services/WorkoutExerciseService";
import type { WorkoutExercise } from "../types/WorkoutExercise"
import {useEffect, useState} from "react"
import type {Exercises} from "../types/Exercises";
import WorkoutExerciseFields from "./WorkoutExerciseFields";
import { optionalNumber, optionalText } from "./workoutExerciseFormUtils";


type WorkoutExerciseUploadFormProps = {
    onSuccess: (workoutExercise: WorkoutExercise[]) => void;
    workoutExercise: WorkoutExercise;
}
function WorkoutExerciseUploadForm({onSuccess, workoutExercise }:WorkoutExerciseUploadFormProps) {
    const [exercises, setExercises] = useState<Exercises[]>([]);

    useEffect(()=>{
        getExercises().then((data)=>{
        setExercises(data);
        });
    },[])

    const handleSubmit = async(event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);

        onSuccess(await updateWorkoutExerciseById({
            id: workoutExercise.id,
            workoutId: workoutExercise.workoutId,
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
            <h2>Atualizar exercicio</h2>

            {exercises.length > 0 && (
                <WorkoutExerciseFields exercises={exercises} initial={workoutExercise} />
            )}

            <button type="submit" >
                Atualizar
            </button>
        </form>
    )
}
export default WorkoutExerciseUploadForm;
