import { useEffect, useState } from "react";
import { getMembers } from "../services/MemberService";
import { getExercises } from "../services/ExerciseService";
import PageHeader from "../components/ui/PageHeader";
import Card from "../components/ui/Card";
import { useNavigate } from "react-router-dom";

function Dashboard() {
    const [memberCount, setMemberCount] = useState<number | null>(null);
    const [exerciseCount, setExerciseCount] = useState<number | null>(null);

    useEffect(() => {
        getMembers().then((data) => setMemberCount(data.length));
    }, []);

    useEffect(() => {
        getExercises().then((data) => setExerciseCount(data.length));
    }, []);

    const navigate = useNavigate();

    return (
        <>
            <PageHeader title="Dashboard" description="Visão geral do GymManager" />

            <div className="stat-grid">
                <Card className="stat-card">
                    <span className="stat-card-label">Alunos cadastrados</span>
                    <span className="stat-card-value">{memberCount ?? "—"}</span>
                </Card>
                <Card className="stat-card">
                    <span className="stat-card-label">Exercícios cadastrados</span>
                    <span className="stat-card-value">{exerciseCount ?? "—"}</span>
                </Card>
            </div>

            <div className="quick-links">

    <button
        className="quick-link-card"
        onClick={() => navigate("/members")}
    >
        <span className="quick-link-icon" aria-hidden="true"></span>
        <span className="quick-link-title">Alunos</span>
        <span className="quick-link-description">
            Gerenciar cadastro de alunos
        </span>
    </button>

    <button
        className="quick-link-card"
        onClick={() => navigate("/exercises")}
    >
        <span className="quick-link-icon" aria-hidden="true"></span>
        <span className="quick-link-title">Exercícios</span>
        <span className="quick-link-description">
            Gerenciar biblioteca de exercícios
        </span>
    </button>

</div>
        </>
    );
}

export default Dashboard;
