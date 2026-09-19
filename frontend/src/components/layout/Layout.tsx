import type { ReactNode } from "react";
import Sidebar from "./Sidebar";
import Topbar from "./Topbar";

type LayoutProps = {
    children: ReactNode;
};

function Layout({ children }: LayoutProps) {
    return (
        <div className="app-shell">
            <Sidebar />
            <div className="app-shell-main">
                <Topbar />
                <main className="app-content">{children}</main>
            </div>
        </div>
    );
}

export default Layout;
