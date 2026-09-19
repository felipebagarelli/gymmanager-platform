import { useLocation } from "react-router-dom";

function getTitle(pathname: string): string {
    if (pathname === "/") return "Dashboard";
    if (pathname === "/members") return "Alunos";
    if (pathname === "/exercises") return "Exercícios";
    if (/\/workouts\/[^/]+\/exercises/.test(pathname)) return "Exercícios do treino";
    if (/\/workouts$/.test(pathname)) return "Treinos do aluno";
    return "GymManager";
}

function Topbar() {
    const location = useLocation();

    return (
        <header className="topbar">
            <h1 className="topbar-title">{getTitle(location.pathname)}</h1>
        </header>
    );
}

export default Topbar;
