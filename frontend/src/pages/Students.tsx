import { useEffect, useState } from "react";
import { getStudents } from "../services/StudentService";
import { getTrainerId } from "../services/AuthService";
import type { Student } from "../types/Student";
import StudentForm from "../components/StudentForm";
import { StudentTable } from "../components/StudentTable";
import PageHeader from "../components/ui/PageHeader";



function Students() {
    const trainerId = getTrainerId() ?? 0;
    const [students, setStudents] = useState<Student[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedStudentId, setSelectedStudentId] = useState<number | null>(null);

    useEffect(() => {
        getStudents(trainerId).then((data) => {
            setStudents(data);
        });
    }, [trainerId]);

    return (
        <>
            <PageHeader
                title="Alunos"
                description="Gerencie o cadastro de alunos"
                actions={
                    <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar Aluno</button>
                }
            />

            {showForm && (
                <div className="form-panel">
                    <StudentForm trainerId={trainerId} onSuccess={(students) => { setStudents(students), setShowForm(false)}} />
                </div>
            )}

            <div className="table-panel">
                <StudentTable
                    students={students}
                    setStudents={setStudents}
                    showUploadForm={showUploadForm}
                    selectedStudentId={selectedStudentId}
                    setShowUploadForm={setShowUploadForm}
                    setSelectedStudentId={setSelectedStudentId}
                    trainerId={trainerId}
                />
            </div>
        </>
    );
}

export default Students;
