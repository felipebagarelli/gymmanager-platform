import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { isAuthenticated } from "../services/AuthService";

type RequireAuthProps = {
    children: ReactNode;
};

function RequireAuth({ children }: RequireAuthProps) {
    if (!isAuthenticated()) {
        return <Navigate to="/login" replace />;
    }

    return children;
}

export default RequireAuth;
