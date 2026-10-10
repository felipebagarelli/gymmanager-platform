package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.dto.EquipmentAnalysis;
import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class EquipmentAnalysisParserTest {

    private static final String VALID = """
            {"reconhecido": true, "equipamento": "Leg press 45°", "musculos": ["Quadríceps", "Glúteos"],
             "preparacao": ["Ajuste o encosto", "Escolha a carga"], "passos": ["Apoie os pés", "Empurre a plataforma"],
             "noPlano": true}
            """;

    @Test
    void parsesAValidAnswer() {
        EquipmentAnalysis out = EquipmentAnalysisParser.parseModelOutput(VALID);

        assertThat(out.recognized()).isTrue();
        assertThat(out.name()).isEqualTo("Leg press 45°");
        assertThat(out.muscles()).containsExactly("Quadríceps", "Glúteos");
        assertThat(out.setup()).containsExactly("Ajuste o encosto", "Escolha a carga");
        assertThat(out.steps()).containsExactly("Apoie os pés", "Empurre a plataforma");
        assertThat(out.inPlan()).isTrue();
    }

    @Test
    void toleratesMarkdownFencesAndTextAroundTheJson() {
        EquipmentAnalysis out = EquipmentAnalysisParser.parseModelOutput("Claro!\n```json\n" + VALID + "\n```\nBom treino");

        assertThat(out.name()).isEqualTo("Leg press 45°");
    }

    @Test
    void unrecognizedEquipment_keepsOnlyTheFlag() {
        EquipmentAnalysis out = EquipmentAnalysisParser.parseModelOutput(
                "{\"reconhecido\": false, \"equipamento\": \"talvez uma cadeira\", \"passos\": [\"x\"], \"noPlano\": true}");

        assertThat(out.recognized()).isFalse();
        assertThat(out.name()).isEmpty();
        assertThat(out.steps()).isEmpty();
        assertThat(out.inPlan()).isFalse();
    }

    @Test
    void rejectsAnswersOutsideTheFormat_soNothingIsStored() {
        assertThatThrownBy(() -> EquipmentAnalysisParser.parseModelOutput("não consegui ver a foto"))
                .isInstanceOf(AiProviderException.class);
        assertThatThrownBy(() -> EquipmentAnalysisParser.parseModelOutput("{quebrado"))
                .isInstanceOf(AiProviderException.class);
        // reconhecido, mas sem nome ou sem passos: resposta inutil
        assertThatThrownBy(() -> EquipmentAnalysisParser.parseModelOutput("{\"reconhecido\": true, \"passos\": [\"a\"]}"))
                .isInstanceOf(AiProviderException.class);
        assertThatThrownBy(() -> EquipmentAnalysisParser.parseModelOutput("{\"equipamento\": \"Supino\", \"passos\": []}"))
                .isInstanceOf(AiProviderException.class);
    }

    @Test
    void limitsAndCleansTheFields() {
        StringBuilder many = new StringBuilder();
        for (int i = 0; i < 12; i++) many.append("\"passo ").append(i).append("\",");
        String json = "{\"equipamento\": \"" + "N".repeat(200) + "\", \"passos\": [" + many + "\"linha\\ncom\\nquebra\", 5, null]}";

        EquipmentAnalysis out = EquipmentAnalysisParser.parseModelOutput(json);

        assertThat(out.name()).hasSize(EquipmentAnalysisParser.MAX_NAME + 1);
        assertThat(out.steps()).hasSize(EquipmentAnalysisParser.MAX_ITEMS);
        assertThat(out.steps()).noneMatch(s -> s.contains("\n"));
    }

    @Test
    void storedJsonRoundTripsAndFeedsTheHistorySummary() {
        EquipmentAnalysis original = EquipmentAnalysisParser.parseModelOutput(VALID);

        EquipmentAnalysis back = EquipmentAnalysisParser.fromStored(EquipmentAnalysisParser.toStoredJson(original)).orElseThrow();

        assertThat(back).isEqualTo(original);
        assertThat(EquipmentAnalysisParser.summary(back)).isEqualTo("Aparelho identificado: Leg press 45°. Trabalha: Quadríceps, Glúteos.");
        assertThat(EquipmentAnalysisParser.fromStored("texto qualquer")).isEmpty();
    }
}
