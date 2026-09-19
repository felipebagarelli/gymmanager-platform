import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {getAllWorkoutExercise} from "../services/WorkoutExerciseService";
import type  {WorkoutExercise } from "../types/WorkoutExercise";
import WorkoutExerciseTable from "../components/WorkoutExerciseTable";
import WorkoutExerciseForm from "../components/WorkoutExerciseForm";
import { getExercises } from "../services/ExerciseService";
import type { Exercises } from "../types/Exercises";
import PageHeader from "../components/ui/PageHeader";


function WorkoutExercises() {
    const [workoutExercise, setWorkoutExercise] = useState<WorkoutExercise[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedWorkoutExerciseId, setSelectedWorkoutExerciseId] = useState<number | null>(null);
    const { memberId, workoutId } = useParams();
    const idWorkout = Number(workoutId);
    const [exercises, setExercises] = useState<Exercises[]>([]);
    const navigate = useNavigate();

    useEffect(()=>{
        getExercises().then((data)=>{
            setExercises(data);
        });},[])


    useEffect(() => {
        getAllWorkoutExercise(idWorkout).then((data) => {
            setWorkoutExercise(data);
        });}, []);


    return (
    <>
        <button className="btn btn-secondary btn-sm back-link" onClick={() => navigate(`/members/${memberId}/workouts`)}>
            ← Voltar para Treinos
        </button>

        <PageHeader
            title="Exercícios do treino"
            description="Gerencie os exercícios deste treino"
            actions={
                <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar exercicio</button>
            }
        />

        {showForm && (
            <div className="form-panel">
                <WorkoutExerciseForm workoutId={idWorkout} onSuccess={(workoutExercise) =>
                {setWorkoutExercise(workoutExercise), setShowForm(false)}}/>
            </div>
        )}

        <div className="table-panel">
            <WorkoutExerciseTable
            workoutExercises={workoutExercise}
            setWorkoutExercises={setWorkoutExercise}
            setShowUploadForm={setShowUploadForm}
            setSelectedWorkoutExerciseId={setSelectedWorkoutExerciseId}
            showUploadForm={showUploadForm}
            workoutId={idWorkout}
            exercises={exercises}
            setShowForm={setShowForm}
            showForm={showForm}
            selectedWorkoutExerciseId={selectedWorkoutExerciseId}
            />
        </div>
    </>)
}

export default WorkoutExercises;