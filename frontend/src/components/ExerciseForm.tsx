import { addExercise } from "../services/ExerciseService";
import type { Exercises } from "../types/Exercises";



type ExerciseFormProps = {
    onSuccess: (exercise: Exercises[]) => void;
};

function ExerciseForm({ onSuccess }: ExerciseFormProps) {
    const  handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const name = formData.get("name") as string;
        const muscleGroup = formData.get("muscleGroup") as string;
        
        
        onSuccess(await addExercise({ name, muscleGroup }));
    }

    return (
        <form onSubmit={handleSubmit}>
            <h2>Adicionar Exercicio</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <label>Grupo Muscular:</label>
            <input type="text" name="muscleGroup" required />
            

            <button  type="submit">
                Adicionar
            </button>
        </form>
    );}
    
export default ExerciseForm;
