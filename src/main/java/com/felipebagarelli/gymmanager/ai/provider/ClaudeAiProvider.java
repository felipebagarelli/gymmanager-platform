package com.felipebagarelli.gymmanager.ai.provider;

import com.anthropic.client.AnthropicClient;
import com.anthropic.errors.AnthropicException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlockParam;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Base64;
import java.util.List;
import java.util.stream.Collectors;

/** Adaptador para a API do Claude (SDK oficial). Nao loga perguntas nem respostas, so contagem de tokens. */
public class ClaudeAiProvider implements AiProvider {

    private static final Logger log = LoggerFactory.getLogger(ClaudeAiProvider.class);

    private final AnthropicClient client;
    private final String model;
    private final long maxTokens;

    public ClaudeAiProvider(AnthropicClient client, String model, long maxTokens) {
        this.client = client;
        this.model = model;
        this.maxTokens = maxTokens;
    }

    MessageCreateParams buildParams(AiRequest request) {
        MessageCreateParams.Builder builder = MessageCreateParams.builder()
                .model(model)
                .maxTokens(request.maxTokens() != null ? request.maxTokens() : maxTokens)
                .system(request.systemPrompt())
                // perguntas curtas de treino: esforco medio basta e reduz custo/latencia
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.MEDIUM).build());

        for (AiTurn turn : request.history()) {
            if (turn.role() == AiRole.USER) {
                builder.addUserMessage(turn.text());
            } else {
                builder.addAssistantMessage(turn.text());
            }
        }
        if (request.image() == null) {
            builder.addUserMessage(request.question());
        } else {
            builder.addUserMessageOfBlockParams(List.of(
                    ContentBlockParam.ofImage(ImageBlockParam.builder()
                            .source(Base64ImageSource.builder()
                                    .mediaType(Base64ImageSource.MediaType.of(request.image().mediaType()))
                                    .data(Base64.getEncoder().encodeToString(request.image().data()))
                                    .build())
                            .build()),
                    ContentBlockParam.ofText(TextBlockParam.builder().text(request.question()).build())));
        }
        return builder.build();
    }

    @Override
    public AiReply ask(AiRequest request) {
        Message response;
        try {
            response = client.messages().create(buildParams(request));
        } catch (AnthropicException e) {
            log.warn("Falha ao chamar o provedor de IA: {}", e.getClass().getSimpleName());
            throw new AiProviderException("O assistente não conseguiu responder agora.", e);
        }

        boolean refused = response.stopReason().map(StopReason.REFUSAL::equals).orElse(false);
        if (refused) {
            throw new AiProviderException("O assistente não pode responder a essa pergunta.");
        }

        String text = response.content().stream()
                .flatMap(block -> block.text().stream())
                .map(textBlock -> textBlock.text())
                .collect(Collectors.joining("\n"))
                .trim();
        if (text.isEmpty()) {
            throw new AiProviderException("O assistente não conseguiu responder agora.");
        }

        log.info("IA respondeu: entrada={} saida={} tokens",
                response.usage().inputTokens(), response.usage().outputTokens());
        return new AiReply(text, response.usage().inputTokens(), response.usage().outputTokens());
    }
}
