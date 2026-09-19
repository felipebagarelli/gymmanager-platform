export interface CreateWorkoutExercise {
    exerciseId: number;
    workoutId: number;
    sets: number;
    reps: number;
    position?: number | null;
    restSeconds?: number | null;
    targetLoad?: number | null;
    notes?: string | null;
}
