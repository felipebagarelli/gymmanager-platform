import WorkoutUploadForm from "./WorkoutUploadForm";
import type { Workout } from "../types/Workout";
import  { unassignWorkout, getAllWorkout } from "../services/WorkoutService";

type WorkoutTableProps = {
    workout: Workout[];
    setWorkout: React.Dispatch<React.SetStateAction<Workout[]>>;
    setShowUploadform: React.Dispatch<React.SetStateAction<boolean>>;
    showUploadForm: boolean;
    setSelectedWorkoutId: React.Dispatch<React.SetStateAction<number | null>>;
    studentId: number;
    selectedWorkoutId: number | null;
};

const WorkoutTable = ({
    workout,
    setWorkout,
    setShowUploadform,
    setSelectedWorkoutId,
    showUploadForm,
    studentId,
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
                            window.location.href = `/students/${studentId}/workouts/${workout.id}/exercises`; } }>
                                Exercícios
                            </button>
                            <button
                                className="btn btn-danger btn-sm"
                                onClick={async () => {
                                    if (confirm("Remover este treino do aluno? (o treino em si é mantido)")) {
                                        await unassignWorkout(workout.id, studentId)
                                        setWorkout(await getAllWorkout(studentId))}}}>
                                            Remover
                                        </button>
                        </td>
                    </tr>,

                    showUploadForm && selectedWorkoutId === workout.id && (
                        <tr key={`form-${workout.id}`}>
                            <td colSpan={8}>
                                <WorkoutUploadForm
                                studentId = {studentId}
                                id = {workout.id}
                                onSuccess = {(updatedWorkouts) => {
                                    setWorkout(updatedWorkouts)
                                    setShowUploadform(false)
                                }}
                                />
                            </td>
                        </tr>

                    )

                ])}
            </tbody>
        </table>)}
export default WorkoutTable;
