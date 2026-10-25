import { useEffect, useState } from "react";
import { getStudents } from "../services/StudentService";
import { getTrainerId } from "../services/AuthService";
import type { Student } from "../types/Student";
import { StudentTable } from "../components/StudentTable";
import PageHeader from "../components/ui/PageHeader";



function Students() {
    const trainerId = getTrainerId() ?? 0;
    const [students, setStudents] = useState<Student[]>([]);
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
                description="Aluno novo entra pelo link de convite de um plano (no app: Planos → Convidar)"
            />

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
