import { useCallback, useEffect, useState } from "react";
import PageHeader from "../components/ui/PageHeader";
import {
    formatPrice,
    getPayoutAccount,
    getPlans,
    getTrainerSubscriptions,
    savePlan,
    startOnboarding,
} from "../services/BillingService";
import type { PayoutAccount, Plan, SubscriptionStatus, TrainerSubscription } from "../types/Billing";

const STATUS_LABEL: Record<SubscriptionStatus, string> = {
    PENDING: "Aguardando pagamento",
    ACTIVE: "Em dia",
    PAST_DUE: "Em atraso",
    CANCELED: "Cancelada",
};

function Payments() {
    const [account, setAccount] = useState<PayoutAccount | null>(null);
    const [plans, setPlans] = useState<Plan[]>([]);
    const [subscriptions, setSubscriptions] = useState<TrainerSubscription[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [name, setName] = useState("");
    const [description, setDescription] = useState("");
    const [price, setPrice] = useState("");

    const load = useCallback(async () => {
        const [acc, list, subs] = await Promise.all([getPayoutAccount(), getPlans(), getTrainerSubscriptions()]);
        setAccount(acc);
        setPlans(list);
        setSubscriptions(subs);
    }, []);

    useEffect(() => {
        const initial = async () => load();
        initial();
    }, [load]);

    const connect = async () => {
        setError(null);
        const result = await startOnboarding();
        if (result.error) return setError(result.error);
        window.location.href = result.data!.url;
    };

    const createPlan = async (event: React.FormEvent) => {
        event.preventDefault();
        setError(null);
        const priceCents = Math.round(parseFloat(price.replace(",", ".")) * 100);
        if (!Number.isFinite(priceCents) || priceCents < 100) return setError("Informe um valor mínimo de R$ 1,00.");
        const result = await savePlan({ name, description, priceCents });
        if (result.error) return setError(result.error);
        setName("");
        setDescription("");
        setPrice("");
        await load();
    };

    const toggle = async (plan: Plan) => {
        setError(null);
        const result = await savePlan(
            { name: plan.name, description: plan.description ?? "", priceCents: plan.priceCents, active: !plan.active },
            plan.id,
        );
        if (result.error) return setError(result.error);
        await load();
    };

    return (
        <div>
            <PageHeader
                title="Pagamentos"
                description="Defina seus planos e receba as mensalidades dos alunos. A plataforma retém uma comissão sobre cada cobrança."
            />

            {error && <p className="form-error" role="alert">{error}</p>}

            <div className="card" style={{ marginBottom: 16 }}>
                <h3>Recebimento</h3>
                {account?.chargesEnabled ? (
                    <p><span className="badge badge-active">Ativo</span> Você já pode cobrar seus alunos.</p>
                ) : (
                    <>
                        <p className="muted">
                            {account?.connected
                                ? "Cadastro iniciado, mas ainda incompleto. Conclua para receber."
                                : "Conecte sua conta para receber os pagamentos dos alunos."}
                        </p>
                        <button className="btn btn-primary" onClick={connect}>
                            {account?.connected ? "Continuar cadastro" : "Conectar conta de recebimento"}
                        </button>
                    </>
                )}
            </div>

            <div className="card" style={{ marginBottom: 16 }}>
                <h3>Meus planos</h3>
                <form onSubmit={createPlan} className="form-panel">
                    <label htmlFor="plan-name">Nome</label>
                    <input id="plan-name" value={name} onChange={(e) => setName(e.target.value)} required maxLength={100} />
                    <label htmlFor="plan-desc">Descrição</label>
                    <input id="plan-desc" value={description} onChange={(e) => setDescription(e.target.value)} maxLength={1000} />
                    <label htmlFor="plan-price">Valor mensal (R$)</label>
                    <input id="plan-price" value={price} onChange={(e) => setPrice(e.target.value)} inputMode="decimal" placeholder="150,00" required />
                    <button className="btn btn-primary" type="submit">Criar plano</button>
                </form>

                {plans.length === 0 ? (
                    <p className="muted">Nenhum plano criado ainda.</p>
                ) : (
                    <table className="table-panel">
                        <thead>
                            <tr><th>Plano</th><th>Valor</th><th>Status</th><th /></tr>
                        </thead>
                        <tbody>
                            {plans.map((plan) => (
                                <tr key={plan.id}>
                                    <td>{plan.name}<br /><span className="muted">{plan.description}</span></td>
                                    <td>{formatPrice(plan.priceCents)}</td>
                                    <td>
                                        <span className={`badge ${plan.active ? "badge-active" : "badge-inactive"}`}>
                                            {plan.active ? "Ativo" : "Inativo"}
                                        </span>
                                    </td>
                                    <td>
                                        <button className="btn btn-secondary btn-sm" onClick={() => toggle(plan)}>
                                            {plan.active ? "Desativar" : "Reativar"}
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            <div className="card">
                <h3>Assinaturas dos alunos</h3>
                {subscriptions.length === 0 ? (
                    <p className="muted">Nenhum aluno assinou ainda.</p>
                ) : (
                    <table className="table-panel">
                        <thead>
                            <tr><th>Aluno</th><th>Plano</th><th>Situação</th><th>Próxima cobrança</th></tr>
                        </thead>
                        <tbody>
                            {subscriptions.map((sub) => (
                                <tr key={sub.id}>
                                    <td>{sub.studentName}</td>
                                    <td>{sub.planName} · {formatPrice(sub.priceCents)}</td>
                                    <td>
                                        <span className={`badge ${sub.status === "ACTIVE" ? "badge-active" : "badge-inactive"}`}>
                                            {STATUS_LABEL[sub.status]}
                                        </span>
                                    </td>
                                    <td>{sub.currentPeriodEnd ? new Date(sub.currentPeriodEnd).toLocaleDateString("pt-BR") : "—"}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}

export default Payments;
