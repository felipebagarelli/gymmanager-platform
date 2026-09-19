import { getExercises } from "../services/ExerciseService";
import { updateWorkoutExerciseById } from "../services/WorkoutExerciseService";
import type { WorkoutExercise } from "../types/WorkoutExercise"
import {useEffect, useState} from "react"
import type {Exercises} from "../types/Exercises";



type WorkoutExerciseUploadFormProps = {
    onSuccess: (workoutExercise: WorkoutExercise[]) => void;
    workoutId: number;
    id: number;
}
function WorkoutExerciseUploadForm({onSuccess, workoutId, id }:WorkoutExerciseUploadFormProps) {
    const [exercises, setExercises] = useState<Exercises[]>([]);

    useEffect(()=>{
        getExercises().then((data)=>{
        setExercises(data);
        });
    },[])

    const handleSubmit = async(event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const exerciseId = Number(formData.get("exerciseId"))
        const sets = Number(formData.get("sets") as string);
        const reps = Number(formData.get("reps") as string);
        //tenho q arrumar isso, tava fazendo para adicionar o exercicio ao treino do mesmo jeito q cria o treino ou exercicio, mas nao eh assim
        // o exercicio ja existe, e o treino ja existe, entao tem q ser um formulario com opcoes dos exercicios para selecionar, e apenas 
        // colocar as repeticoes e series, ja esta manejado desta forma no backend, tenho q fazer assima gora aqui manipulando com os id dos treinos e exercicios
        // ainda falta eu corrigir isso, pra depois ajeitar o css, e depois voltar pro backend terminar as coisas de seguranca e afins ( OK)

        onSuccess(await updateWorkoutExerciseById({id, workoutId, exerciseId, sets, reps }))
    }


    return (
        <form onSubmit={handleSubmit}>
            <h2>Atualizar exercicio</h2>

            <label>Exercicio:</label>
            <select name="exerciseId" required>
                <option value="">Selecione um exercicio</option>
                {exercises.map((exercise) => (
                <option key={exercise.id} value={exercise.id}>
                {exercise.name}
                </option>
                ))}
            </select>
            <label>Series:</label>
            <input type="number" name="sets" required/>
            <label>Repeticoes:</label>
            <input type="number" name="reps" required/>

            <button type="submit" >
                Atualizar
            </button>
        

        </form>
    )//nao estou conseguindo adicionar um novo exercisewworkout, tenho q ver isso (OK)!
}
export default WorkoutExerciseUploadForm;