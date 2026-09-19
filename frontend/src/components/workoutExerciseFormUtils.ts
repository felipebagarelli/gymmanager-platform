export const optionalNumber = (value: FormDataEntryValue | null): number | null => {
    const text = (value as string | null) ?? "";
    return text.trim() === "" ? null : Number(text);
};

export const optionalText = (value: FormDataEntryValue | null): string | null => {
    const text = ((value as string | null) ?? "").trim();
    return text === "" ? null : text;
};
