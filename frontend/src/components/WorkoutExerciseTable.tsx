
import type { WorkoutExercise } from "../types/WorkoutExercise";
import type { Exercises } from "../types/Exercises";
import { deleteWorkoutExerciseById } from "../services/WorkoutExerciseService";
import { getAllWorkoutExercise } from "../services/WorkoutExerciseService";
import WorkoutExerciseUploadForm from "./workoutExerciseUploadForm"


type WorkoutExerciseTableProps = {
    workoutExercises: WorkoutExercise[];
    setWorkoutExercises: React.Dispatch<React.SetStateAction<WorkoutExercise[]>>;
    setShowUploadForm: React.Dispatch<React.SetStateAction<boolean>>;
    showUploadForm: boolean;
    setShowForm: React.Dispatch<React.SetStateAction<boolean>>;
    showForm: boolean;
    workoutId: number;
    exercises:Exercises[] ;
    setSelectedWorkoutExerciseId: React.Dispatch<React.SetStateAction<number | null>>;
    selectedWorkoutExerciseId: number | null;
    
};

const WorkoutExerciseTable = ({ 
    selectedWorkoutExerciseId,
    workoutExercises, 
    setWorkoutExercises, 
    setShowUploadForm, 
    showUploadForm,
    exercises,
    workoutId,
    setSelectedWorkoutExerciseId
}: WorkoutExerciseTableProps) => {
    return (
        <table>
            <thead>
                <tr>
                    <th>Exercicio</th>
                    <th>Musculo</th>
                    <th>Series</th>
                    <th>Repeticoes</th>
                    <th>acoes</th>
                </tr>
            </thead>
            <tbody>
            
                {workoutExercises.map((workoutExercise) => [
                    <tr key={workoutExercise.id}>
                        <td>{exercises.find(exercise => 
                            exercise.id === workoutExercise.exerciseId)?.name}</td>
                        <td>{exercises.find(exercise => 
                            exercise.id === workoutExercise.exerciseId)?.muscleGroup}</td>
                        <td>{workoutExercise.sets}</td>
                        <td>{workoutExercise.reps}</td>
                        <td>
                            <button
                                className="btn btn-edit btn-sm"
                                onClick={() => {
                                    setSelectedWorkoutExerciseId(workoutExercise.id);
                                    setShowUploadForm(true);
                                }}
                            >
                                Edit
                            </button>
                            <button
                                className="btn btn-danger btn-sm"
                                onClick={async () => {
                                    console.log(workoutExercise);
                                    await deleteWorkoutExerciseById(workoutExercise.id);
                                    setWorkoutExercises(
                                        await getAllWorkoutExercise(workoutExercise.workoutId)
                                    );

                                }}
                            >
                                Delete
                            </button>
                        </td>
                    </tr>,
                    showUploadForm && selectedWorkoutExerciseId === workoutExercise.id && (
                        <tr key={`form-${workoutExercise.id}`}>
                            <td colSpan={8}>
                                <WorkoutExerciseUploadForm
                                id={workoutExercise.id}
                                workoutId={workoutId}
                                onSuccess={(newWorkoutExercise) => {
                                    setWorkoutExercises(newWorkoutExercise)
                                    setShowUploadForm(false)
                                }}
                                />

                            </td>

                        </tr>
                    )
                
                ])}
            </tbody>
        </table>)}
export default WorkoutExerciseTable