package com.felipebagarelli.gymmanager.account.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/** DTOs do cadastro aberto, confirmacao de e-mail e troca de senha. */
public final class AccountDtos {

    private AccountDtos() {
    }

    /** Cadastro do aluno pelo app. De 12 a 17 anos, o responsavel e obrigatorio. */
    public record RegisterStudentRequest(
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Email @Size(max = 255) String email,
            @NotBlank @Size(min = 8, max = 72) String password,
            @NotNull LocalDate birthDate,
            @Size(max = 120) String guardianName,
            @Email @Size(max = 255) String guardianEmail,
            @NotBlank String termsVersion,
            @AssertTrue(message = "É preciso aceitar os termos de uso e a política de privacidade.") boolean acceptTerms,
            @AssertTrue(message = "É preciso autorizar o uso dos dados de treino e saúde.") boolean acceptHealthData
    ) {
    }

    public record RegisterStudentResponse(String email, boolean guardianRequired) {
    }

    public record EmailRequest(@NotBlank @Email String email) {
    }

    public record VerifyEmailRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "\\d{6}", message = "O código tem 6 números.") String code
    ) {
    }

    /** Depois de confirmar o e-mail: se ainda falta o responsavel autorizar, para quem foi o pedido. */
    public record VerifyEmailResponse(boolean guardianPending, String guardianEmail) {
    }

    public record ResetPasswordRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "\\d{6}", message = "O código tem 6 números.") String code,
            @NotBlank @Size(min = 8, max = 72) String newPassword
    ) {
    }

    /** Versao vigente dos documentos e onde le-los (vazio = ainda em preparacao). */
    public record LegalInfoResponse(String termsVersion, String termsUrl, String privacyUrl, int minimumAge, int adultAge) {
    }

    public record MessageResponse(String message) {
    }
}
