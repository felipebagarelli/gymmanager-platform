export interface WorkoutExercise {
    id: number;
    workoutId: number;
    exerciseId: number;
    sets: number;
    reps: number;
    position?: number | null;
    restSeconds?: number | null;
    targetLoad?: number | null;
    notes?: string | null;
}
