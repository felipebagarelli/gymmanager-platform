import { addStudent } from "../services/StudentService";
import type { Student } from "../types/Student";

type StudentFormProps = {
    onSuccess: (students: Student[]) => void;
    trainerId: number;
};

function StudentForm({ onSuccess, trainerId }: StudentFormProps) {
    const  handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const name = formData.get("name") as string;
        const email = formData.get("email") as string;
        const password = formData.get("password") as string;
        const phone = formData.get("phone") as string;
        const birthDate = formData.get("birthDate") as string;
        const height = parseFloat(formData.get("height") as string);
        const weight = parseFloat(formData.get("weight") as string);
        const goal = formData.get("goal") as string;


        onSuccess(await addStudent(trainerId, { name, email, password, phone, birthDate, height, weight, goal }));
    }

    return (
        <form onSubmit={handleSubmit}>
            <h2>Adicionar aluno</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <label>Email:</label>
            <input type="email" name="email" required />
            <label>Senha:</label>
            <input type="password" name="password" minLength={8} required />
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
                Adicionar
            </button>
        </form>
    );}

export default StudentForm;
