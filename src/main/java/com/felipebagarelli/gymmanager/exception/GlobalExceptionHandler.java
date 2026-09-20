package com.felipebagarelli.gymmanager.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.ai.provider.AiUnavailableException;

import com.felipebagarelli.gymmanager.billing.provider.InvalidWebhookException;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProviderException;
import com.felipebagarelli.gymmanager.billing.provider.PaymentUnavailableException;

import java.time.Instant;

@RestControllerAdvice
public class GlobalExceptionHandler{

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

  private ResponseEntity<ErrorResponse> build(HttpStatus status, String message, HttpServletRequest request){
    return ResponseEntity
            .status(status)
            .body(new ErrorResponse(status.value(), message, Instant.now(), request.getRequestURI()));
  }

  @ExceptionHandler(ResourceNotFoundException.class)
  public ResponseEntity<ErrorResponse> handleResourceNotFound(ResourceNotFoundException ex, HttpServletRequest request){
    return build(HttpStatus.NOT_FOUND, ex.getMessage(), request);
  }

  @ExceptionHandler(EmailAlreadyInUseException.class)
  public ResponseEntity<ErrorResponse> handleEmailAlreadyInUse(EmailAlreadyInUseException ex, HttpServletRequest request){
    return build(HttpStatus.CONFLICT, ex.getMessage(), request);
  }

  @ExceptionHandler(ConflictException.class)
  public ResponseEntity<ErrorResponse> handleConflict(ConflictException ex, HttpServletRequest request){
    return build(HttpStatus.CONFLICT, ex.getMessage(), request);
  }

  @ExceptionHandler(PaymentRequiredException.class)
  public ResponseEntity<ErrorResponse> handlePaymentRequired(PaymentRequiredException ex, HttpServletRequest request){
    return build(HttpStatus.PAYMENT_REQUIRED, ex.getMessage(), request);
  }

  @ExceptionHandler(PaymentUnavailableException.class)
  public ResponseEntity<ErrorResponse> handlePaymentUnavailable(PaymentUnavailableException ex, HttpServletRequest request){
    return build(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request);
  }

  @ExceptionHandler(PaymentProviderException.class)
  public ResponseEntity<ErrorResponse> handlePaymentProvider(PaymentProviderException ex, HttpServletRequest request){
    return build(HttpStatus.BAD_GATEWAY, ex.getMessage(), request);
  }

  @ExceptionHandler(InvalidWebhookException.class)
  public ResponseEntity<ErrorResponse> handleInvalidWebhook(InvalidWebhookException ex, HttpServletRequest request){
    return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
  }

  @ExceptionHandler(RateLimitExceededException.class)
  public ResponseEntity<ErrorResponse> handleRateLimit(RateLimitExceededException ex, HttpServletRequest request){
    return build(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), request);
  }

  @ExceptionHandler(AiUnavailableException.class)
  public ResponseEntity<ErrorResponse> handleAiUnavailable(AiUnavailableException ex, HttpServletRequest request){
    return build(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request);
  }

  @ExceptionHandler(AiProviderException.class)
  public ResponseEntity<ErrorResponse> handleAiProvider(AiProviderException ex, HttpServletRequest request){
    log.warn("Falha do provedor de IA em {}", request.getRequestURI());
    return build(HttpStatus.BAD_GATEWAY, ex.getMessage(), request);
  }

  @ExceptionHandler(InvalidCredentialsException.class)
  public ResponseEntity<ErrorResponse> handleInvalidCredentials(InvalidCredentialsException ex, HttpServletRequest request){
    return build(HttpStatus.UNAUTHORIZED, ex.getMessage(), request);
  }

  @ExceptionHandler(AccessDeniedException.class)
  public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request){
    return build(HttpStatus.FORBIDDEN, ex.getMessage(), request);
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidationError(MethodArgumentNotValidException ex, HttpServletRequest request){
    String message = ex.getBindingResult().getFieldErrors().stream()
            .findFirst()
            .map(error -> error.getField() + ": " + error.getDefaultMessage())
            .orElse("Requisição inválida.");
    return build(HttpStatus.BAD_REQUEST, message, request);
  }

  @ExceptionHandler(NoResourceFoundException.class)
  public ResponseEntity<ErrorResponse> handleNoResource(NoResourceFoundException ex, HttpServletRequest request){
    return build(HttpStatus.NOT_FOUND, "Recurso não encontrado.", request);
  }

  @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
  public ResponseEntity<ErrorResponse> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex, HttpServletRequest request){
    return build(HttpStatus.METHOD_NOT_ALLOWED, "Método HTTP não suportado para este recurso.", request);
  }

  @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
  public ResponseEntity<ErrorResponse> handleMalformedRequest(Exception ex, HttpServletRequest request){
    return build(HttpStatus.BAD_REQUEST, "Requisição malformada.", request);
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleUnexpectedError(Exception ex, HttpServletRequest request){
    log.error("Erro não tratado em {}", request.getRequestURI(), ex);
    return build(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno inesperado.", request);
  }

}
