import { deleteExerciseById, getExercises } from "../services/ExerciseService";
import type { Exercises } from "../types/Exercises";
import ExerciseUploadForm from "./ExerciseUploadForm";



type ExerciseTableProps = {
    exercises: Exercises[];
    setExercises: React.Dispatch<React.SetStateAction<Exercises[]>>;
    showUploadForm: boolean;
    selectedExerciseId: number | null;
    setShowUploadForm: React.Dispatch<React.SetStateAction<boolean>>;
    setSelectedExerciseId: React.Dispatch<React.SetStateAction<number | null>>;
};

const ExerciseTable = ({
    exercises,
    setExercises,
    showUploadForm,
    selectedExerciseId,
    setShowUploadForm,
    setSelectedExerciseId
}: ExerciseTableProps) => {
    return (
        <table>
            <thead>
                <tr>
                    <th>Nome</th>
                    <th>Músculo Alvo</th>
                    <th>Ações</th>
                </tr>
            </thead>
            <tbody>
                {exercises.map((exercise) => [
                    <tr key={exercise.id}>
                        <td>{exercise.name}</td>
                        <td>{exercise.muscleGroup}</td>
                        <td>
                            <button
                                className="btn btn-edit btn-sm"
                                onClick={() => {
                                    setSelectedExerciseId(exercise.id);
                                    setShowUploadForm(true);
                                }}
                            >
                                Editar
                            </button>
                            <button
                                className="btn btn-danger btn-sm"
                                onClick={async () => {
                                    await deleteExerciseById(exercise.id);
                                    setExercises(
                                        await getExercises())

                                }}
                            >
                                Excluir
                            </button>
                        </td>
                    </tr>,
                    showUploadForm && selectedExerciseId === exercise.id && (
                        <tr key={`upload-${exercise.id}`}>
                            <td colSpan={3}>
                                <ExerciseUploadForm
                                    exerciseId={exercise.id}
                                    onSuccess={(updatedExercises) => {
                                        setExercises(updatedExercises);
                                        setShowUploadForm(false);
                                    }}
                                />
                            </td>
                        </tr>
                    )
                ])}
            </tbody>
        </table>
    );
};

export default ExerciseTable;