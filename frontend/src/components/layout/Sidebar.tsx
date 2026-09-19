import { NavLink } from "react-router-dom";

const navItems = [
    { to: "/", label: "Dashboard", end: true },
    { to: "/members", label: "Alunos", end: false },
    { to: "/exercises", label: "Exercícios", end: false },
];

function Sidebar() {
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
                    </NavLink>
                ))}
            </nav>
        </aside>
    );
}

export default Sidebar;
