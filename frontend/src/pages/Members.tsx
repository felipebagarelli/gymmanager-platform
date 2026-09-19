import { useEffect, useState } from "react";
import { getMembers } from "../services/MemberService";
import type { Member } from "../types/Member";
import MemberForm from "../components/MemberForm";
import { MemberTable } from "../components/MemberTable";
import PageHeader from "../components/ui/PageHeader";



function Members() {
    const [members, setMembers] = useState<Member[]>([]);
    const [showForm, setShowForm] = useState(false);
    const [showUploadForm, setShowUploadForm] = useState(false);
    const [selectedMemberId, setSelectedMemberId] = useState<number | null>(null);

    useEffect(() => {
        getMembers().then((data) => {
            setMembers(data);
        });
    }, []);

    return (
        <>
            <PageHeader
                title="Alunos"
                description="Gerencie o cadastro de alunos da academia"
                actions={
                    <button className="btn btn-primary" onClick={() => setShowForm(true)}>Adicionar Membro</button>
                }
            />

            {showForm && (
                <div className="form-panel">
                    <MemberForm onSuccess={(members) => { setMembers(members), setShowForm(false)}} />
                </div>
            )}

            <div className="table-panel">
                <MemberTable
                    members={members}
                    setMembers={setMembers}
                    showUploadForm={showUploadForm}
                    selectedMemberId={selectedMemberId}
                    setShowUploadForm={setShowUploadForm}
                    setSelectedMemberId={setSelectedMemberId}
                />
            </div>
        </>
    );
}

export default Members;
