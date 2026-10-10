package com.felipebagarelli.gymmanager.ai.provider;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.MessageParam;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ClaudeAiProviderTest {

    @Test
    void buildParams_ordersHistoryThenQuestion_withoutNetwork() {
        AnthropicClient client = AnthropicOkHttpClient.builder().apiKey("chave-falsa-de-teste").build();
        ClaudeAiProvider provider = new ClaudeAiProvider(client, "claude-opus-5", 500);

        MessageCreateParams params = provider.buildParams(new AiRequest("SYS",
                List.of(new AiTurn(AiRole.USER, "p1"), new AiTurn(AiRole.ASSISTANT, "r1")), "p2"));

        assertThat(params.messages()).hasSize(3);
        assertThat(params.maxTokens()).isEqualTo(500);
    }

    @Test
    void buildParams_withImage_sendsImageAndTextBlocksInTheLastUserTurn() {
        AnthropicClient client = AnthropicOkHttpClient.builder().apiKey("chave-falsa-de-teste").build();
        ClaudeAiProvider provider = new ClaudeAiProvider(client, "claude-opus-5", 500);
        byte[] jpeg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0};

        MessageCreateParams params = provider.buildParams(new AiRequest("SYS", List.of(), "como uso?",
                new AiImage("image/jpeg", jpeg)));

        assertThat(params.messages()).hasSize(1);
        MessageParam last = params.messages().get(0);
        assertThat(last.content().isBlockParams()).isTrue();
        assertThat(last.content().asBlockParams()).hasSize(2);
        assertThat(last.content().asBlockParams().get(0).isImage()).isTrue();
        assertThat(last.content().asBlockParams().get(1).isText()).isTrue();
    }

    @Test
    void unavailableProvider_alwaysThrows() {
        assertThatThrownBy(() -> new UnavailableAiProvider().ask(new AiRequest("s", List.of(), "q")))
                .isInstanceOf(AiUnavailableException.class);
    }

    /** Teste real, opt-in: so roda com AI_API_KEY definida no ambiente. */
    @Test
    @EnabledIfEnvironmentVariable(named = "AI_API_KEY", matches = ".+")
    void live_realCall() {
        AnthropicClient client = AnthropicOkHttpClient.builder().apiKey(System.getenv("AI_API_KEY")).build();
        AiReply reply = new ClaudeAiProvider(client, "claude-opus-5", 300)
                .ask(new AiRequest("Responda em uma frase.", List.of(), "O que é agachamento?"));
        assertThat(reply.text()).isNotBlank();
    }
}
