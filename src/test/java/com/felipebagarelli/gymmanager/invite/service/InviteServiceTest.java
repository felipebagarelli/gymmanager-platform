package com.felipebagarelli.gymmanager.invite.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.hub.service.HubService;
import com.felipebagarelli.gymmanager.invite.dto.InviteDtos.InviteLinkResponse;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class InviteServiceTest {

    private final PlanRepository plans = mock(PlanRepository.class);
    private final HubService hub = mock(HubService.class);
    private TrainerProfile joao;
    private Plan mensal;
    private InviteService service;

    @BeforeEach
    void setUp() {
        joao = TrainerProfile.builder().id(5L).displayName("João Personal").headline("Hipertrofia")
                .user(User.builder().email("joao@example.com").role(Role.TRAINER).active(true).build()).build();
        mensal = Plan.builder().id(50L).trainer(joao).name("Mensal").priceCents(15000).active(true).build();
        when(plans.findById(50L)).thenReturn(Optional.of(mensal));
        when(plans.findByInviteCode(anyString())).thenAnswer(i ->
                i.getArgument(0).equals(mensal.getInviteCode()) ? Optional.of(mensal) : Optional.empty());
        when(plans.save(any(Plan.class))).thenAnswer(i -> i.getArgument(0));
        when(hub.canHire(joao)).thenReturn(true);
        service = new InviteService(plans, hub, "https://api.example.com/");
    }

    @Test
    void link_isCreatedOnce_resetChangesIt_andTheOldStopsWorking() {
        InviteLinkResponse first = service.link(50L, "joao@example.com");
        assertThat(first.code()).hasSize(10).matches("[a-z2-9]+");
        assertThat(first.url()).isEqualTo("https://api.example.com/convite/" + first.code());
        assertThat(service.link(50L, "joao@example.com").code()).isEqualTo(first.code());

        InviteLinkResponse second = service.reset(50L, "joao@example.com");
        assertThat(second.code()).isNotEqualTo(first.code());
        assertThatThrownBy(() -> service.preview(first.code())).isInstanceOf(ResourceNotFoundException.class);
        assertThat(service.preview(second.code().toUpperCase()).planName()).isEqualTo("Mensal");
    }

    @Test
    void onlyTheOwner_andOnlyActivePlans() {
        assertThatThrownBy(() -> service.link(50L, "outro@example.com")).isInstanceOf(AccessDeniedException.class);
        mensal.setActive(false);
        assertThatThrownBy(() -> service.link(50L, "joao@example.com")).isInstanceOf(ConflictException.class);
    }

    @Test
    void preview_showsOnlyPublicData_andHidesDeactivatedPlansAndInactiveTrainers() {
        String code = service.link(50L, "joao@example.com").code();
        var preview = service.preview(code);
        assertThat(preview.trainerName()).isEqualTo("João Personal");
        assertThat(preview.priceCents()).isEqualTo(15000);
        assertThat(preview.available()).isTrue();

        joao.getUser().setActive(false);
        assertThatThrownBy(() -> service.preview(code)).isInstanceOf(ResourceNotFoundException.class);
        joao.getUser().setActive(true);
        mensal.setActive(false);
        assertThatThrownBy(() -> service.preview(code)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void accept_hiresThroughTheHubRules() {
        String code = service.link(50L, "joao@example.com").code();
        when(hub.hireByInvite(mensal, "ana@example.com")).thenReturn(new UrlResponse("https://checkout.stripe.test/x"));

        assertThat(service.accept(code, "ana@example.com").url()).isEqualTo("https://checkout.stripe.test/x");
        verify(hub).hireByInvite(mensal, "ana@example.com");
        assertThatThrownBy(() -> service.accept("naoexiste", "ana@example.com")).isInstanceOf(ResourceNotFoundException.class);
    }
}
