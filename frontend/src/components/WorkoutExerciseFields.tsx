import type { Exercises } from "../types/Exercises";
import type { WorkoutExercise } from "../types/WorkoutExercise";

type Props = {
    exercises: Exercises[];
    initial?: WorkoutExercise;
};



function WorkoutExerciseFields({ exercises, initial }: Props) {
    return (
        <>
            <label>Exercicio:</label>
            <select name="exerciseId" defaultValue={initial?.exerciseId ?? ""} required>
                <option value="">Selecione um exercicio</option>
                {exercises.map((exercise) => (
                    <option key={exercise.id} value={exercise.id}>
                        {exercise.name}
                    </option>
                ))}
            </select>
            <label>Series:</label>
            <input type="number" name="sets" min={1} defaultValue={initial?.sets} required />
            <label>Repeticoes:</label>
            <input type="number" name="reps" min={1} defaultValue={initial?.reps} required />
            <label>Ordem no treino (opcional):</label>
            <input type="number" name="position" min={1} defaultValue={initial?.position ?? ""} />
            <label>Descanso em segundos (opcional):</label>
            <input type="number" name="restSeconds" min={0} defaultValue={initial?.restSeconds ?? ""} />
            <label>Carga alvo em kg (opcional):</label>
            <input type="number" name="targetLoad" min={0} step="0.5" defaultValue={initial?.targetLoad ?? ""} />
            <label>Observacao (opcional):</label>
            <input type="text" name="notes" defaultValue={initial?.notes ?? ""} />
        </>
    );
}

export default WorkoutExerciseFields;
