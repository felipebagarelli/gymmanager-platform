import { addMember} from "../services/MemberService";
import type { Member } from "../types/Member";

type MemberFormProps = {
    onSuccess: (members: Member[]) => void;
};

function MemberForm({ onSuccess }: MemberFormProps) {
    const  handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const formData = new FormData(event.currentTarget);
        const name = formData.get("name") as string;
        const email = formData.get("email") as string;
        const phone = formData.get("phone") as string;
        const birthDate = formData.get("birthDate") as string;
        const height = parseFloat(formData.get("height") as string);
        const weight = parseFloat(formData.get("weight") as string);
        
        
        onSuccess(await addMember({ name, email, phone, birthDate, height, weight, active: true }));
    }

    return (
        <form onSubmit={handleSubmit}>
            <h2>Adicionar membro</h2>

            <label>Nome:</label>
            <input type="text" name="name" required />
            <label>Email:</label>
            <input type="email" name="email" required />
            <label>Telefone:</label>
            <input type="text" name="phone" required />
            <label>Data de nascimento:</label>
            <input type="date" name="birthDate" required />
            <label>Altura:</label>
            <input type="number" name="height" step="0.01" required />
            <label>Peso:</label>
            <input type="number" name="weight" step="0.01" required />

            <button  type="submit">
                Adicionar
            </button>
        </form>
    );}
    
export default MemberForm;
