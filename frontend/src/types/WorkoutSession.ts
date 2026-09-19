export interface Performance {
    id: number;
    workoutExerciseId: number;
    setNumber: number;
    reps: number;
    loadKg: number | null;
}

export interface WorkoutSession {
    id: number;
    workoutId: number;
    studentId: number;
    startedAt: string;
    finishedAt: string | null;
    performances: Performance[];
}
