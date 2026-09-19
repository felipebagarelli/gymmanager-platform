import type { Member } from "../types/Member";
import { deleteMember } from "../services/MemberService";
import MemberUploadForm from "./MemberUploadForm";
import { useNavigate } from "react-router-dom";




type MemberTableProps = {
    members: Member[];
    setMembers: React.Dispatch<React.SetStateAction<Member[]>>;
    showUploadForm: boolean;
    selectedMemberId: number | null;
    setShowUploadForm: React.Dispatch<React.SetStateAction<boolean>>;
    setSelectedMemberId: React.Dispatch<React.SetStateAction<number | null>>;
};

export const MemberTable = ({
    members,
    setMembers,
    showUploadForm,
    selectedMemberId,
    setShowUploadForm,
    setSelectedMemberId
}: MemberTableProps) => {

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
                {members.map((member) => [
                    <tr key={member.id}>
                        <td>{member.name}</td>
                        <td>{member.email}</td>
                        <td>{member.phone}</td>
                        <td>{member.birthDate}</td>
                        <td>{member.height} m</td>
                        <td>{member.weight} kg</td>
                        <td>
                            <span className={`badge ${member.active ? "badge-active" : "badge-inactive"}`}>
                                {member.active ? "Ativo" : "Inativo"}
                            </span>
                        </td>

                        <td>
                            <button
                                className="btn btn-edit btn-sm"
                                onClick={() => {
                                    setSelectedMemberId(member.id);
                                    setShowUploadForm(true);
                                }}
                            >
                                Editar
                            </button>

                            <button
                                className="btn btn-danger btn-sm"
                                onClick={async () => {
                                    await deleteMember(member.id);
                                    setMembers(
                                        prev => prev.filter(m => m.id !== member.id)
                                    );
                                }}
                            >
                                Excluir
                            </button>

                            <button
                                className="btn btn-secondary btn-sm"
                                onClick={() => {navigate(`/members/${member.id}/workouts`)}}
                                >
                                    Treinos
                                </button>
                        </td>
                    </tr>,

                    showUploadForm &&
                    selectedMemberId === member.id && (
                        <tr key={`form-${member.id}`}>
                            <td colSpan={8}>
                                <MemberUploadForm
                                    memberId={member.id}
                                    onSuccess={(updatedMembers) => {
                                        setMembers(updatedMembers);
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