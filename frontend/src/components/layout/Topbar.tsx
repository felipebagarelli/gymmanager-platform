import { useLocation, useNavigate } from "react-router-dom";
import { logout } from "../../services/AuthService";

function getTitle(pathname: string): string {
    if (pathname === "/") return "Dashboard";
    if (pathname === "/students") return "Alunos";
    if (pathname === "/exercises") return "Exercícios";
    if (pathname === "/workouts") return "Biblioteca de treinos";
    if (pathname === "/chat") return "Mensagens";
    if (/\/students\/[^/]+\/sessions$/.test(pathname)) return "Histórico de sessões";
    if (/\/workouts\/[^/]+\/exercises/.test(pathname)) return "Exercícios do treino";
    if (/\/workouts$/.test(pathname)) return "Treinos do aluno";
    return "GymManager";
}

function Topbar() {
    const location = useLocation();
    const navigate = useNavigate();

    const handleLogout = () => {
        logout();
        navigate("/login");
    };

    return (
        <header className="topbar">
            <h1 className="topbar-title">{getTitle(location.pathname)}</h1>
            <button className="btn btn-sm" onClick={handleLogout}>
                Sair
            </button>
        </header>
    );
}

export default Topbar;
