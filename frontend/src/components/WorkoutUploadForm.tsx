import type React from "react"
import type { Workout } from "../types/Workout"
import { updateWorkoutById } from "../services/WorkoutService"

type WorkoutUploadFormProps = {
    onSuccess: (workout: Workout[]) => void
    memberId: number 
    id: number
}

function WorkoutUploadForm ({onSuccess, memberId, id}: WorkoutUploadFormProps) {
    const handleSubmit = async  (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const name = formData.get("name") as string;

        onSuccess(await updateWorkoutById({id, name, memberId}))
    }

    return(
        <form onSubmit={handleSubmit}>
            <h2>Atualizar nome Treino</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <button type="submit">
                Atualizar nome
            </button>

        </form>
    )
}
export default WorkoutUploadForm