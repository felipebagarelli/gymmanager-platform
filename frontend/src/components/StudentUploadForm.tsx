import { updateStudent } from "../services/StudentService";
import type { Student } from "../types/Student";

type StudentUploadFormProps = {
    onSuccess: (students: Student[]) => void;
    trainerId: number;
    studentId: number;
};

function StudentUploadForm({ studentId, trainerId, onSuccess }: StudentUploadFormProps) {
    const  handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const id: number = (studentId);
        const name = formData.get("name") as string;
        const phone = formData.get("phone") as string;
        const birthDate = formData.get("birthDate") as string;
        const height = parseFloat(formData.get("height") as string);
        const weight = parseFloat(formData.get("weight") as string);
        const goal = formData.get("goal") as string;

        onSuccess(await updateStudent(trainerId, { id, name, phone, birthDate, height, weight, goal }));
    }

    return (
        <form onSubmit={handleSubmit}>
            <h2>Editar aluno</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <label>Telefone:</label>
            <input type="text" name="phone" required />
            <label>Data de nascimento:</label>
            <input type="date" name="birthDate" required />
            <label>Altura:</label>
            <input type="number" name="height" step="0.01" required />
            <label>Peso:</label>
            <input type="number" name="weight" step="0.01" required />
            <label>Objetivo:</label>
            <input type="text" name="goal" />

            <button  type="submit">
                Editar
            </button>
        </form>
    );}
export default StudentUploadForm;
