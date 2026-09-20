import type { WorkoutSession } from "../types/WorkoutSession";

export interface ProgressPoint {
    date: string;
    maxLoadKg: number | null;
    totalReps: number;
}

export interface ExerciseProgress {
    exerciseName: string;
    points: ProgressPoint[];
}

export const bestLoad = (progress: ExerciseProgress): number | null => {
    const loads = progress.points.map((p) => p.maxLoadKg).filter((v): v is number => v != null);
    return loads.length === 0 ? null : Math.max(...loads);
};

export const lastDelta = (progress: ExerciseProgress): number | null => {
    const loads = progress.points.map((p) => p.maxLoadKg).filter((v): v is number => v != null);
    if (loads.length < 2) return null;
    return loads[loads.length - 1] - loads[loads.length - 2];
};

/**
 * Evolução por exercício a partir das sessões finalizadas (mais antigas primeiro).
 * `exerciseNameByWorkoutExerciseId` mapeia o item do plano (mesmo de treinos antigos) ao nome do exercício.
 */
export const computeEvolution = (
    sessions: WorkoutSession[],
    exerciseNameByWorkoutExerciseId: Record<number, string>,
): ExerciseProgress[] => {
    const finished = [...sessions]
        .filter((s) => s.finishedAt !== null && s.performances.length > 0)
        .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime());

    const byExercise = new Map<string, ProgressPoint[]>();
    for (const session of finished) {
        const grouped = new Map<string, { loads: number[]; reps: number }>();
        for (const performance of session.performances) {
            const name = exerciseNameByWorkoutExerciseId[performance.workoutExerciseId];
            if (!name) continue; // exercicio removido do plano desde entao
            const entry = grouped.get(name) ?? { loads: [], reps: 0 };
            if (performance.loadKg != null) entry.loads.push(performance.loadKg);
            entry.reps += performance.reps;
            grouped.set(name, entry);
        }
        grouped.forEach((entry, name) => {
            const points = byExercise.get(name) ?? [];
            points.push({
                date: session.startedAt,
                maxLoadKg: entry.loads.length === 0 ? null : Math.max(...entry.loads),
                totalReps: entry.reps,
            });
            byExercise.set(name, points);
        });
    }

    return [...byExercise.entries()]
        .map(([exerciseName, points]) => ({ exerciseName, points }))
        .sort((a, b) => a.exerciseName.localeCompare(b.exerciseName, "pt-BR"));
};
