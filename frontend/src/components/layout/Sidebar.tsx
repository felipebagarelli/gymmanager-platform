import { NavLink } from "react-router-dom";
import { useUnreadTotal } from "../../hooks/useUnreadTotal";

const navItems: { to: string; label: string; end: boolean; icon?: string }[] = [
    { to: "/", label: "Dashboard", end: true },
    { to: "/students", label: "Alunos", end: false },
    { to: "/workouts", label: "Treinos", end: false },
    { to: "/chat", label: "Mensagens", end: false },
    { to: "/pagamentos", label: "Pagamentos", end: false },
    { to: "/exercises", label: "Exercícios", end: false },
];

function Sidebar() {
    const unread = useUnreadTotal();

    return (
        <aside className="sidebar">
            <div className="sidebar-brand">
                <span className="sidebar-brand-mark">GM</span>
                <span className="sidebar-brand-name">GymManager</span>
            </div>

            <nav className="sidebar-nav">
                {navItems.map((item) => (
                    <NavLink
                        key={item.to}
                        to={item.to}
                        end={item.end}
                        className={({ isActive }) =>
                            `sidebar-link${isActive ? " active" : ""}`
                        }
                    >
                        <span className="sidebar-link-icon" aria-hidden="true">
                            {item.icon}
                        </span>
                        <span>{item.label}</span>
                        {item.to === "/chat" && unread > 0 && (
                            <span className="nav-badge" aria-label={`${unread} mensagens não lidas`}>
                                {unread}
                            </span>
                        )}
                    </NavLink>
                ))}
            </nav>
        </aside>
    );
}

export default Sidebar;
