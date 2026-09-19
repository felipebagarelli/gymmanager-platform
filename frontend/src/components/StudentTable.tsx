import type { Student } from "../types/Student";
import { deactivateStudent } from "../services/StudentService";
import StudentUploadForm from "./StudentUploadForm";
import { useNavigate } from "react-router-dom";




type StudentTableProps = {
    students: Student[];
    setStudents: React.Dispatch<React.SetStateAction<Student[]>>;
    showUploadForm: boolean;
    selectedStudentId: number | null;
    setShowUploadForm: React.Dispatch<React.SetStateAction<boolean>>;
    setSelectedStudentId: React.Dispatch<React.SetStateAction<number | null>>;
    trainerId: number;
};

export const StudentTable = ({
    students,
    setStudents,
    showUploadForm,
    selectedStudentId,
    setShowUploadForm,
    setSelectedStudentId,
    trainerId
}: StudentTableProps) => {

    const navigate = useNavigate();

    return (
        <table>
            <thead>
                <tr>
                    <th>Nome</th>
                    <th>Email</th>
                    <th>Telefone</th>
                    <th>Data de nascimento</th>
                    <th>Altura</th>
                    <th>Peso</th>
                    <th>Status</th>
                    <th>Ações</th>
                </tr>
            </thead>

            <tbody>
                {students.map((student) => [
                    <tr key={student.id}>
                        <td>{student.name}</td>
                        <td>{student.email}</td>
                        <td>{student.phone}</td>
                        <td>{student.birthDate}</td>
                        <td>{student.height} m</td>
                        <td>{student.weight} kg</td>
                        <td>
                            <span className={`badge ${student.active ? "badge-active" : "badge-inactive"}`}>
                                {student.active ? "Ativo" : "Inativo"}
                            </span>
                        </td>

                        <td>
                            <button
                                className="btn btn-edit btn-sm"
                                onClick={() => {
                                    setSelectedStudentId(student.id);
                                    setShowUploadForm(true);
                                }}
                            >
                                Editar
                            </button>

                            <button
                                className="btn btn-danger btn-sm"
                                onClick={async () => {
                                    if (confirm("Tem certeza que deseja desativar este aluno?")) {
                                        setStudents(await deactivateStudent(trainerId, student.id));
                                    }
                                }}
                            >
                                Desativar
                            </button>

                            <button
                                className="btn btn-secondary btn-sm"
                                onClick={() => {navigate(`/students/${student.id}/workouts`)}}
                                >
                                    Treinos
                                </button>
                        </td>
                    </tr>,

                    showUploadForm &&
                    selectedStudentId === student.id && (
                        <tr key={`form-${student.id}`}>
                            <td colSpan={8}>
                                <StudentUploadForm
                                    studentId={student.id}
                                    trainerId={trainerId}
                                    onSuccess={(updatedStudents) => {
                                        setStudents(updatedStudents);
                                        setShowUploadForm(false);
                                    }}
                                />
                            </td>
                        </tr>
                    )
                ])}
            </tbody>
        </table>
    );
};
