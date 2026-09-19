import type { ReactNode } from "react";

type PageHeaderProps = {
    title: string;
    description?: string;
    actions?: ReactNode;
};

function PageHeader({ title, description, actions }: PageHeaderProps) {
    return (
        <div className="page-header">
            <div>
                <h2 className="page-header-title">{title}</h2>
                {description && <p className="page-header-description">{description}</p>}
            </div>
            {actions && <div className="page-header-actions">{actions}</div>}
        </div>
    );
}

export default PageHeader;
