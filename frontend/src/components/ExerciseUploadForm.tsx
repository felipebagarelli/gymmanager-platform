import { updateExercise } from "../services/ExerciseService";
import type {Exercises} from "../types/Exercises"


type ExerciseUploadFormProps = {
    onSuccess: (exercises: Exercises[]) => void;
    exerciseId: number;
};

function ExerciseUploadForm({onSuccess, exerciseId}: ExerciseUploadFormProps) {
    const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const id: number = (exerciseId);
        const name = formData.get("name") as string;
        const muscleGroup = formData.get("muscleGroup") as string;

        const exercise: Exercises = {id, name, muscleGroup};
        onSuccess(await updateExercise(exercise));
    }


    return (
        <form onSubmit={handleSubmit}>
            <h2>Editar exercício</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <label>Grupo muscular:</label>
            <input type="text" name="muscleGroup" required />
            <button type="submit">
                Editar
            </button>
        </form>
    );  
} export default ExerciseUploadForm;