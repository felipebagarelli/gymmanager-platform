import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { getStudentSessions } from "../services/SessionService";
import { getMyWorkouts } from "../services/WorkoutService";
import { getExercises } from "../services/ExerciseService";
import { getAllWorkoutExercise } from "../services/WorkoutExerciseService";
import type { WorkoutSession } from "../types/WorkoutSession";
import PageHeader from "../components/ui/PageHeader";
import Card from "../components/ui/Card";

const formatDateTime = (value: string) => new Date(value).toLocaleString("pt-BR");

const formatDuration = (start: string, end: string) => {
    const minutes = Math.max(0, Math.round((new Date(end).getTime() - new Date(start).getTime()) / 60000));
    return minutes < 1 ? "menos de 1 min" : `${minutes} min`;
};

function StudentSessions() {
    const { studentId } = useParams();
    const id = Number(studentId);
    const navigate = useNavigate();
    const [sessions, setSessions] = useState<WorkoutSession[]>([]);
    const [workoutNames, setWorkoutNames] = useState<Record<number, string>>({});
    const [exerciseNames, setExerciseNames] = useState<Record<number, string>>({});
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const load = async () => {
            const [sessionList, workouts, exercises] = await Promise.all([
                getStudentSessions(id),
                getMyWorkouts(),
                getExercises(),
            ]);

            const exerciseById = Object.fromEntries(exercises.map((exercise) => [exercise.id, exercise.name]));
            const workoutIds = [...new Set(sessionList.map((session) => session.workoutId))];
            const planLists = await Promise.all(workoutIds.map((workoutId) => getAllWorkoutExercise(workoutId)));

            const names: Record<number, string> = {};
            planLists.forEach((plan) => {
                if (Array.isArray(plan)) {
                    plan.forEach((item) => {
                        names[item.id] = exerciseById[item.exerciseId] ?? `Exercício #${item.exerciseId}`;
                    });
                }
            });

            setWorkoutNames(Object.fromEntries(workouts.map((workout) => [workout.id, workout.name])));
            setExerciseNames(names);
            setSessions(sessionList);
            setLoading(false);
        };
        load();
    }, [id]);

    return (
        <>
            <button className="btn btn-secondary btn-sm back-link" onClick={() => navigate(`/students/${id}/workouts`)}>
                ← Voltar para Treinos
            </button>

            <PageHeader title="Histórico de sessões" description="Treinos executados por este aluno" />

            {!loading && sessions.length === 0 && (
                <p className="muted">Este aluno ainda não executou nenhum treino.</p>
            )}

            {sessions.map((session) => (
                <Card key={session.id} className="session-card">
                    <div className="session-header">
                        <strong>{workoutNames[session.workoutId] ?? `Treino #${session.workoutId}`}</strong>
                        <span className={`badge ${session.finishedAt ? "badge-active" : "badge-inactive"}`}>
                            {session.finishedAt ? "Finalizada" : "Em andamento"}
                        </span>
                    </div>
                    <p className="muted">
                        Início: {formatDateTime(session.startedAt)}
                        {session.finishedAt && ` · Duração: ${formatDuration(session.startedAt, session.finishedAt)}`}
                    </p>

                    {session.performances.length === 0 ? (
                        <p className="muted">Nenhuma série registrada.</p>
                    ) : (
                        <table>
                            <thead>
                                <tr>
                                    <th>Exercício</th>
                                    <th>Série</th>
                                    <th>Repetições</th>
                                    <th>Carga</th>
                                </tr>
                            </thead>
                            <tbody>
                                {session.performances.map((performance) => (
                                    <tr key={performance.id}>
                                        <td>{exerciseNames[performance.workoutExerciseId] ?? `#${performance.workoutExerciseId}`}</td>
                                        <td>{performance.setNumber}</td>
                                        <td>{performance.reps}</td>
                                        <td>{performance.loadKg != null ? `${performance.loadKg} kg` : "—"}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}
                </Card>
            ))}
        </>
    );
}

export default StudentSessions;
