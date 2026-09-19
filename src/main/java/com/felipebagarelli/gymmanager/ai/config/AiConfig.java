package com.felipebagarelli.gymmanager.ai.config;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.ClaudeAiProvider;
import com.felipebagarelli.gymmanager.ai.provider.UnavailableAiProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AiConfig {

    @Bean
    public AiProvider aiProvider(@Value("${app.ai.api-key:}") String apiKey,
                                 @Value("${app.ai.model}") String model,
                                 @Value("${app.ai.max-tokens}") long maxTokens) {
        if (apiKey == null || apiKey.isBlank()) {
            return new UnavailableAiProvider();
        }
        AnthropicClient client = AnthropicOkHttpClient.builder().apiKey(apiKey).build();
        return new ClaudeAiProvider(client, model, maxTokens);
    }
}
