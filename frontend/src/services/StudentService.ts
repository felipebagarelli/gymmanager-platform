import { apiFetch } from "./httpClient";
import type { CreateStudent } from "../types/CreateStudent";
import type { UpdateStudent } from "../types/UpdateStudent";
import type { Student } from "../types/Student";

export const getStudents = async (trainerId: number): Promise<Student[]> => {
    const response = await apiFetch(`/api/v1/trainers/${trainerId}/students`);
    return await response.json();
};

export const addStudent = async (trainerId: number, createStudent: CreateStudent): Promise<Student[]> => {
    await apiFetch(`/api/v1/trainers/${trainerId}/students`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(createStudent)
    });
    return getStudents(trainerId);
};

export const getStudentById = async (id: number): Promise<Student> => {
    const response = await apiFetch(`/api/v1/students/${id}`);
    return await response.json();
};

export const updateStudent = async (trainerId: number, student: UpdateStudent): Promise<Student[]> => {
    await apiFetch(`/api/v1/students/${student.id}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(student)
    });
    return getStudents(trainerId);
};

export const deactivateStudent = async (trainerId: number, id: number): Promise<Student[]> => {
    await apiFetch(`/api/v1/students/${id}`, {
        method: 'DELETE'
    });
    return getStudents(trainerId);
};
