package com.felipebagarelli.gymmanager.chat.controller;

import com.felipebagarelli.gymmanager.chat.dto.ConversationSummary;
import com.felipebagarelli.gymmanager.chat.dto.MessageResponse;
import com.felipebagarelli.gymmanager.chat.dto.SendMessageRequest;
import com.felipebagarelli.gymmanager.chat.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/conversations")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @GetMapping
    public List<ConversationSummary> myConversations(@AuthenticationPrincipal Jwt jwt) {
        return chatService.myConversations(jwt.getSubject());
    }

    @GetMapping("/{id}/messages")
    public List<MessageResponse> messages(@PathVariable Long id,
                                          @RequestParam(required = false) Long after,
                                          @RequestParam(required = false) Integer limit,
                                          @AuthenticationPrincipal Jwt jwt) {
        return chatService.messages(id, after, limit, jwt.getSubject());
    }

    @PostMapping("/{id}/messages")
    public MessageResponse send(@PathVariable Long id,
                                @RequestBody @Valid SendMessageRequest request,
                                @AuthenticationPrincipal Jwt jwt) {
        return chatService.send(id, request.body(), jwt.getSubject());
    }

    @PostMapping("/{id}/read")
    public void markRead(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        chatService.markRead(id, jwt.getSubject());
    }
}
