import type React from "react"
import type { Workout } from "../types/Workout"
import { addWorkout } from "../services/WorkoutService"

type WorkoutFormProps = {
    onSuccess: (workout: Workout[]) => void
    memberId: number 
}

function WorkoutForm ({onSuccess, memberId}: WorkoutFormProps) {
    const handleSubmit = async  (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const name = formData.get("name") as string;

        onSuccess(await addWorkout({name, memberId}))
    }

    return(
        <form onSubmit={handleSubmit}>
            <h2>Adicionar Treino</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <button type="submit">
                Adicionar
            </button>

        </form>
    )
}
export default WorkoutForm