import {useEffect, useState} from "react"
import type { Exercises } from "../types/Exercises";
import { getExercises } from "../services/ExerciseService";
import ExerciseForm from "../components/ExerciseForm";
import ExerciseTable from "../components/ExerciseTable";
import PageHeader from "../components/ui/PageHeader";

function Exercise() {

    const [exercises, setExercises] = useState<Exercises[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedExerciseId, setSelectedExerciseId] = useState<number | null>(null);


    useEffect(() => {
        getExercises().then((data) => {
        setExercises(data);
        });
    }, []);

    return (
        <>
            <PageHeader
                title="Exercícios"
                description="Gerencie a biblioteca de exercícios"
                actions={
                    <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar Exercicio</button>
                }
            />

            {showForm && (
                <div className="form-panel">
                    <ExerciseForm onSuccess={(exercise) => { setExercises(exercise), setShowForm(false) }}/>
                </div>
            )}

            <div className="table-panel">
                <ExerciseTable
                    exercises = {exercises}
                    setExercises = {setExercises}
                    showUploadForm = {showUploadForm}
                    setShowUploadForm = {setShowUploadForm}
                    selectedExerciseId = {selectedExerciseId}
                    setSelectedExerciseId = {setSelectedExerciseId}
                />
            </div>
        </>


    )} export default Exercise;