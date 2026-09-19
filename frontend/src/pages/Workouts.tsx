import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {getAllWorkout} from "../services/WorkoutService";
import type { Workout } from "../types/Workout";
import WorkoutTable from "../components/WorkoutTable";
import WorkoutForm from "../components/WorkoutForm";
import PageHeader from "../components/ui/PageHeader";


function Workouts() {
    const [workout, setWorkout] = useState<Workout[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedWorkoutId, setSelectedWorkoutId] = useState<number | null>(null);
    const { memberId } = useParams();
    const id = Number(memberId);
    const navigate = useNavigate();

    useEffect(() => {
        getAllWorkout(id).then((data) => {
            setWorkout(data);
        });}, [id]);


    return (
    <>
        <button className="btn btn-secondary btn-sm back-link" onClick={() => navigate("/members")}>
            ← Voltar para Alunos
        </button>

        <PageHeader
            title="Treinos do aluno"
            description="Gerencie os treinos deste aluno"
            actions={
                <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar Treino</button>
            }
        />

        {showForm && (
            <div className="form-panel">
                <WorkoutForm memberId={id} onSuccess={(workout) =>
                {setWorkout(workout), setShowForm(false)}}/>
            </div>
        )}

        <div className="table-panel">
            <WorkoutTable
            workout={workout}
            setWorkout={setWorkout}
            setShowUploadform={setShowUploadForm}
            setSelectedWorkoutId={setSelectedWorkoutId}
            showUploadForm={showUploadForm}
            memberId={id}
            selectedWorkoutId={selectedWorkoutId}
            />
        </div>
    </>)
}

export default Workouts;