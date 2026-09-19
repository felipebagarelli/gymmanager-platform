import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { login } from "../services/AuthService";
import Card from "../components/ui/Card";

function Login() {
    const navigate = useNavigate();
    const [error, setError] = useState<string | null>(null);

    const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        setError(null);

        const formData = new FormData(event.currentTarget);
        const email = formData.get("email") as string;
        const password = formData.get("password") as string;

        try {
            await login(email, password);
            navigate("/");
        } catch {
            setError("E-mail ou senha inválidos.");
        }
    };

    return (
        <div className="login-page">
            <Card className="login-card">
                <form onSubmit={handleSubmit}>
                    <h2>Entrar</h2>

                    <label>Email:</label>
                    <input type="email" name="email" required />

                    <label>Senha:</label>
                    <input type="password" name="password" required />

                    {error && <p className="login-error">{error}</p>}

                    <button type="submit">Entrar</button>
                </form>
            </Card>
        </div>
    );
}

export default Login;
