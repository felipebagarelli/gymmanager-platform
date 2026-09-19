import WorkoutUploadForm from "./WorkoutUploadForm";
import type { Workout } from "../types/Workout";

type WorkoutTableProps = {
    workout: Workout[];
    setWorkout: React.Dispatch<React.SetStateAction<Workout[]>>;
    setShowUploadform: React.Dispatch<React.SetStateAction<boolean>>;
    showUploadForm: boolean;
    setSelectedWorkoutId: React.Dispatch<React.SetStateAction<number | null>>;
    memberId: number;
    selectedWorkoutId: number | null;
};

const WorkoutTable = ({ 
    workout, 
    setWorkout, 
    setShowUploadform,
    setSelectedWorkoutId,
    showUploadForm, 
    memberId, 
    selectedWorkoutId
}: WorkoutTableProps) => {
    return (
        <table>
            <thead>
                <tr>
                    <th>Treino</th>
                    <th>acoes</th>
                </tr>
            </thead>
            <tbody>
               {workout.map((workout) => [
                    <tr key={workout.id}>
                        <td>{workout.name}</td>
                        <td>
                            <button
                                className="btn btn-edit btn-sm"
                                onClick={() => {
                                    setSelectedWorkoutId(workout.id);
                                    setShowUploadform(true);
                                }}

                            >
                                Editar Nome
                            </button>
                            <button
                                className="btn btn-secondary btn-sm"
                                onClick={() => {
                            window.location.href = `/members/${memberId}/workouts/${workout.id}/exercises`; } }>
                                Exercícios
                            </button>
                        </td>
                    </tr>,

                    showUploadForm && selectedWorkoutId === workout.id && (
                        <tr key={`form-${workout.id}`}>
                            <td colSpan={8}>
                                <WorkoutUploadForm
                                memberId = {memberId}
                                id = {workout.id} 
                                onSuccess = {(updatedWorkouts) => {
                                    setWorkout(updatedWorkouts)
                                }}
                                />
                            </td>
                        </tr>                        

                    )
                
                ])}
            </tbody>
        </table>)}
export default WorkoutTable;
