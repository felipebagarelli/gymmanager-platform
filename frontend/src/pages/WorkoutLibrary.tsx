import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { createTemplate, deleteTemplate, getMyWorkouts, renameTemplate } from "../services/WorkoutService";
import type { Workout } from "../types/Workout";
import PageHeader from "../components/ui/PageHeader";

function WorkoutLibrary() {
    const [workouts, setWorkouts] = useState<Workout[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [editingId, setEditingId] = useState<number | null>(null);
    const [error, setError] = useState<string | null>(null);
    const navigate = useNavigate();

    useEffect(() => {
        getMyWorkouts().then(setWorkouts);
    }, []);

    const handleCreate = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const name = new FormData(event.currentTarget).get("name") as string;
        setError(null);
        setWorkouts(await createTemplate(name));
        setShowForm(false);
    };

    const handleRename = async (event: React.FormEvent<HTMLFormElement>, id: number) => {
        event.preventDefault();
        const name = new FormData(event.currentTarget).get("name") as string;
        setError(null);
        setWorkouts(await renameTemplate(id, name));
        setEditingId(null);
    };

    const handleDelete = async (workout: Workout) => {
        if (!confirm(`Excluir o treino "${workout.name}"?`)) return;
        const message = await deleteTemplate(workout.id);
        if (message) {
            setError(message);
            return;
        }
        setError(null);
        setWorkouts(await getMyWorkouts());
    };

    return (
        <>
            <PageHeader
                title="Biblioteca de treinos"
                description="Treinos reutilizáveis: monte uma vez e atribua a vários alunos"
                actions={
                    <button className="btn btn-primary" onClick={() => setShowForm(true)}>Novo treino</button>
                }
            />

            {showForm && (
                <div className="form-panel">
                    <form onSubmit={handleCreate}>
                        <h2>Novo treino</h2>
                        <label>Nome:</label>
                        <input type="text" name="name" required />
                        <button type="submit">Criar</button>
                    </form>
                </div>
            )}

            {error && <p className="form-error">{error}</p>}

            <div className="table-panel">
                <table>
                    <thead>
                        <tr>
                            <th>Treino</th>
                            <th>Ações</th>
                        </tr>
                    </thead>
                    <tbody>
                        {workouts.map((workout) => [
                            <tr key={workout.id}>
                                <td>{workout.name}</td>
                                <td>
                                    <button className="btn btn-edit btn-sm" onClick={() => setEditingId(workout.id)}>
                                        Editar nome
                                    </button>
                                    <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/workouts/${workout.id}/exercises`)}>
                                        Exercícios
                                    </button>
                                    <button className="btn btn-danger btn-sm" onClick={() => handleDelete(workout)}>
                                        Excluir
                                    </button>
                                </td>
                            </tr>,
                            editingId === workout.id && (
                                <tr key={`edit-${workout.id}`}>
                                    <td colSpan={2}>
                                        <form onSubmit={(event) => handleRename(event, workout.id)}>
                                            <h2>Renomear treino</h2>
                                            <label>Nome:</label>
                                            <input type="text" name="name" defaultValue={workout.name} required />
                                            <button type="submit">Salvar</button>
                                        </form>
                                    </td>
                                </tr>
                            ),
                        ])}
                    </tbody>
                </table>
            </div>
        </>
    );
}

export default WorkoutLibrary;
