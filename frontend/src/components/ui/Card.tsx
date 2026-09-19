import type { ReactNode } from "react";

type CardProps = {
    children: ReactNode;
    className?: string;
};

function Card({ children, className = "" }: CardProps) {
    return <div className={`card ${className}`.trim()}>{children}</div>;
}

export default Card;
