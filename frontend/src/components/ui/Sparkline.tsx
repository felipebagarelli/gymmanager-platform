type SparklineProps = {
    values: number[];
    width?: number;
    height?: number;
};

/** Gráfico de linha simples em SVG, sem dependência externa. */
function Sparkline({ values, width = 240, height = 56 }: SparklineProps) {
    if (values.length === 0) return null;
    const padding = 6;
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min < 0.001 ? 1 : max - min;

    const xAt = (i: number) => (values.length === 1 ? width / 2 : padding + ((width - 2 * padding) * i) / (values.length - 1));
    const yAt = (v: number) => padding + (height - 2 * padding) * (1 - (v - min) / range);

    const path = values.map((v, i) => `${i === 0 ? "M" : "L"}${xAt(i).toFixed(1)},${yAt(v).toFixed(1)}`).join(" ");

    return (
        <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Evolução da carga">
            <path d={path} fill="none" stroke="var(--color-primary)" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
            {values.map((v, i) => (
                <circle key={i} cx={xAt(i)} cy={yAt(v)} r={i === values.length - 1 ? 4 : 2.5} fill="var(--color-primary)" />
            ))}
        </svg>
    );
}

export default Sparkline;
