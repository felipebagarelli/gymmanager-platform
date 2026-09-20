package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.PayoutAccountResponse;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/** Conta de recebimento do personal (onboarding no provedor de pagamentos). */
@Service
public class PayoutAccountService {

    private final PaymentProvider paymentProvider;
    private final TrainerPayoutAccountRepository accountRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final String appUrl;

    public PayoutAccountService(PaymentProvider paymentProvider,
                                TrainerPayoutAccountRepository accountRepository,
                                TrainerProfileRepository trainerProfileRepository,
                                @Value("${app.billing.app-url}") String appUrl) {
        this.paymentProvider = paymentProvider;
        this.accountRepository = accountRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.appUrl = appUrl;
    }

    private TrainerProfile trainerOf(String email) {
        return trainerProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
    }

    /** Cria a conta no provedor (se ainda nao existir) e devolve o link para concluir o cadastro. */
    public UrlResponse startOnboarding(String trainerEmail) {
        TrainerProfile trainer = trainerOf(trainerEmail);
        TrainerPayoutAccount account = accountRepository.findByTrainerId(trainer.getId()).orElse(null);
        if (account == null) {
            String externalId = paymentProvider.createConnectedAccount(trainerEmail);
            account = accountRepository.save(TrainerPayoutAccount.builder()
                    .trainer(trainer)
                    .stripeAccountId(externalId)
                    .chargesEnabled(false)
                    .updatedAt(LocalDateTime.now())
                    .build());
        }
        String base = appUrl.endsWith("/") ? appUrl.substring(0, appUrl.length() - 1) : appUrl;
        return new UrlResponse(paymentProvider.createOnboardingLink(
                account.getStripeAccountId(), base + "/pagamentos?retorno=ok", base + "/pagamentos?retorno=refazer"));
    }

    /** Se ainda nao esta habilitada, consulta o provedor (nao depende do webhook chegar). */
    public PayoutAccountResponse status(String trainerEmail) {
        TrainerPayoutAccount account = accountRepository.findByTrainerId(trainerOf(trainerEmail).getId()).orElse(null);
        if (account == null) {
            return new PayoutAccountResponse(false, false);
        }
        if (!account.isChargesEnabled()) {
            try {
                boolean enabled = paymentProvider.isChargesEnabled(account.getStripeAccountId());
                if (enabled) {
                    account.setChargesEnabled(true);
                    account.setUpdatedAt(LocalDateTime.now());
                    accountRepository.save(account);
                }
            } catch (RuntimeException ignored) {
                // provedor fora do ar: mostra o ultimo estado conhecido
            }
        }
        return new PayoutAccountResponse(true, account.isChargesEnabled());
    }
}
