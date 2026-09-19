import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { assignWorkout, getAllWorkout, getMyWorkouts } from "../services/WorkoutService";
import type { Workout } from "../types/Workout";
import WorkoutTable from "../components/WorkoutTable";
import WorkoutForm from "../components/WorkoutForm";
import PageHeader from "../components/ui/PageHeader";


function Workouts() {
    const [workout, setWorkout] = useState<Workout[]>([]);
    const [library, setLibrary] = useState<Workout[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showAssign, setShowAssign] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedWorkoutId, setSelectedWorkoutId] = useState<number | null>(null);
    const [error, setError] = useState<string | null>(null);
    const { studentId } = useParams();
    const id = Number(studentId);
    const navigate = useNavigate();

    useEffect(() => {
        getAllWorkout(id).then((data) => {
            setWorkout(data);
        });
        getMyWorkouts().then(setLibrary);
    }, [id]);

    const assignable = library.filter((template) => !workout.some((assigned) => assigned.id === template.id));

    const handleAssign = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const workoutId = Number(new FormData(event.currentTarget).get("workoutId"));
        const message = await assignWorkout(workoutId, id);
        if (message) {
            setError(message);
            return;
        }
        setError(null);
        setWorkout(await getAllWorkout(id));
        setShowAssign(false);
    };

    return (
    <>
        <button className="btn btn-secondary btn-sm back-link" onClick={() => navigate("/students")}>
            ← Voltar para Alunos
        </button>

        <PageHeader
            title="Treinos do aluno"
            description="Gerencie os treinos deste aluno"
            actions={
                <>
                    <button className="btn btn-secondary" onClick={() => navigate(`/students/${id}/sessions`)}>Histórico</button>
                    <button className="btn btn-secondary" onClick={() => setShowAssign(true)}>Atribuir treino existente</button>
                    <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar Treino</button>
                </>
            }
        />

        {showAssign && (
            <div className="form-panel">
                <form onSubmit={handleAssign}>
                    <h2>Atribuir treino existente</h2>
                    {assignable.length === 0 ? (
                        <p className="muted">Nenhum treino disponível na biblioteca para atribuir.</p>
                    ) : (
                        <>
                            <label>Treino:</label>
                            <select name="workoutId" required>
                                <option value="">Selecione um treino</option>
                                {assignable.map((template) => (
                                    <option key={template.id} value={template.id}>{template.name}</option>
                                ))}
                            </select>
                            <button type="submit">Atribuir</button>
                        </>
                    )}
                </form>
            </div>
        )}

        {showForm && (
            <div className="form-panel">
                <WorkoutForm studentId={id} onSuccess={(workout) =>
                {setWorkout(workout); setShowForm(false); getMyWorkouts().then(setLibrary)}}/>
            </div>
        )}

        {error && <p className="form-error">{error}</p>}

        <div className="table-panel">
            <WorkoutTable
            workout={workout}
            setWorkout={setWorkout}
            setShowUploadform={setShowUploadForm}
            setSelectedWorkoutId={setSelectedWorkoutId}
            showUploadForm={showUploadForm}
            studentId={id}
            selectedWorkoutId={selectedWorkoutId}
            />
        </div>
    </>)
}

export default Workouts;
