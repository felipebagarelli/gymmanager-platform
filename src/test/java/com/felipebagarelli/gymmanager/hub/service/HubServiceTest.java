package com.felipebagarelli.gymmanager.hub.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileRequest;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileResponse;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.TrainerCard;
import com.felipebagarelli.gymmanager.hub.entity.TrainerSpecialty;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class HubServiceTest {

    private TrainerProfile joao;
    private TrainerProfile bia;
    private TrainerProfile semPlano;
    private StudentProfile ana;
    private TrainerProfileRepository trainers;
    private PlanRepository plans;
    private TrainerStudentRepository links;
    private SubscriptionService subscriptions;
    private HubService service;

    private static TrainerProfile trainer(long id, String name, String email, String headline, String city, String specialties, boolean online) {
        return TrainerProfile.builder().id(id).displayName(name).headline(headline).city(city).state("SP").online(online)
                .specialties(specialties).listed(true).bio("Bio de " + name)
                .user(User.builder().email(email).role(Role.TRAINER).active(true).build()).build();
    }

    @BeforeEach
    void setUp() {
        joao = trainer(5, "João Personal", "joao@example.com", "Hipertrofia para iniciantes", "São Paulo", "HYPERTROPHY,BEGINNERS", true);
        bia = trainer(6, "Bia Treinos", "bia@example.com", "Emagrecimento com saúde", "Campinas", "WEIGHT_LOSS", false);
        bia.setInPerson(true);
        semPlano = trainer(7, "Carlos", "carlos@example.com", "Força", "Santos", "STRENGTH", true);
        trainers = mock(TrainerProfileRepository.class);
        when(trainers.findByListedTrueOrderByDisplayNameAsc()).thenReturn(List.of(bia, semPlano, joao));
        when(trainers.findById(5L)).thenReturn(Optional.of(joao));
        when(trainers.findById(7L)).thenReturn(Optional.of(semPlano));
        when(trainers.findByUserEmail("joao@example.com")).thenReturn(Optional.of(joao));
        when(trainers.save(any(TrainerProfile.class))).thenAnswer(i -> i.getArgument(0));

        plans = mock(PlanRepository.class);
        Plan joaoMensal = Plan.builder().id(50L).trainer(joao).name("Mensal").priceCents(15000).active(true).build();
        when(plans.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(5L)).thenReturn(List.of(joaoMensal));
        when(plans.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(6L)).thenReturn(List.of(
                Plan.builder().id(60L).trainer(bia).name("Básico").priceCents(9900).active(true).build()));
        when(plans.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(7L)).thenReturn(List.of());
        when(plans.findById(50L)).thenReturn(Optional.of(joaoMensal));
        when(plans.findById(60L)).thenReturn(Optional.of(Plan.builder().id(60L).trainer(bia).active(true).build()));

        TrainerPayoutAccountRepository payouts = mock(TrainerPayoutAccountRepository.class);
        when(payouts.findByTrainerId(anyLong())).thenReturn(Optional.of(TrainerPayoutAccount.builder().chargesEnabled(true).build()));

        ana = StudentProfile.builder().id(9L).name("Ana").birthDate(LocalDate.of(1995, 1, 1))
                .user(User.builder().email("ana@example.com").role(Role.STUDENT).build()).build();
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findByUserEmail("ana@example.com")).thenReturn(Optional.of(ana));
        links = mock(TrainerStudentRepository.class);
        when(links.findByStudentId(anyLong())).thenReturn(Optional.empty());
        subscriptions = mock(SubscriptionService.class);
        when(subscriptions.subscribe(anyLong(), anyString())).thenReturn(new UrlResponse("https://checkout.stripe.test/x"));

        Clock clock = Clock.fixed(Instant.parse("2026-10-18T12:00:00Z"), ZoneId.of("America/Sao_Paulo"));
        service = new HubService(trainers, plans, payouts, students, links, subscriptions, clock);
    }

    @Test
    void search_showsOnlyTrainersReadyToBeHired_neverContactData() {
        List<TrainerCard> all = service.search(null, null, null, null);
        assertThat(all).extracting(TrainerCard::displayName).containsExactly("Bia Treinos", "João Personal"); // sem plano fica fora
        assertThat(all.get(1).fromPriceCents()).isEqualTo(15000);

        assertThat(service.search("hipertrofia", null, null, null)).extracting(TrainerCard::id).containsExactly(5L);
        assertThat(service.search("saude", null, null, null)).extracting(TrainerCard::id).containsExactly(6L); // sem acento
        assertThat(service.search(null, TrainerSpecialty.WEIGHT_LOSS, null, null)).extracting(TrainerCard::id).containsExactly(6L);
        assertThat(service.search(null, null, true, null)).extracting(TrainerCard::id).containsExactly(5L);
        assertThat(service.search(null, null, null, "campi")).extracting(TrainerCard::id).containsExactly(6L);

        assertThatThrownBy(() -> service.detail(7L)).isInstanceOf(ResourceNotFoundException.class);
        assertThat(service.detail(5L).plans()).extracting(p -> p.priceCents()).containsExactly(15000);
    }

    @Test
    void publicProfile_saysWhatIsMissing() {
        joao.setListed(false);
        joao.setHeadline(null);
        PublicProfileResponse before = service.myPublicProfile("joao@example.com");
        assertThat(before.visible()).isFalse();
        assertThat(before.missing()).hasSize(2);

        PublicProfileResponse after = service.updatePublicProfile(new PublicProfileRequest(true, "  Treino   em casa ", "Bio",
                "Santos", "sp", true, false, Set.of(TrainerSpecialty.HEALTH)), "joao@example.com");
        assertThat(after.visible()).isTrue();
        assertThat(after.headline()).isEqualTo("Treino em casa");
        assertThat(after.state()).isEqualTo("SP");
        assertThat(after.specialties()).containsExactly(TrainerSpecialty.HEALTH);

        assertThatThrownBy(() -> service.updatePublicProfile(new PublicProfileRequest(true, "X", null, null, null,
                false, false, null), "joao@example.com")).isInstanceOf(ConflictException.class);
    }

    @Test
    void hire_createsAPendingLink_andOpensTheTrainersCheckout() {
        UrlResponse url = service.hire(5L, 50L, "ana@example.com");

        assertThat(url.url()).isEqualTo("https://checkout.stripe.test/x");
        ArgumentCaptor<TrainerStudent> link = ArgumentCaptor.forClass(TrainerStudent.class);
        verify(links).save(link.capture());
        assertThat(link.getValue().getStatus()).isEqualTo(TrainerStudentStatus.INVITED);
        assertThat(link.getValue().getTrainer()).isSameAs(joao);
        verify(subscriptions).subscribe(50L, "ana@example.com");
    }

    @Test
    void hire_rules() {
        // plano de outro personal
        assertThatThrownBy(() -> service.hire(5L, 60L, "ana@example.com")).isInstanceOf(ResourceNotFoundException.class);
        // personal que nao aparece
        assertThatThrownBy(() -> service.hire(7L, 50L, "ana@example.com")).isInstanceOf(ResourceNotFoundException.class);
        // ja tem personal
        when(links.findByStudentId(9L)).thenReturn(Optional.of(TrainerStudent.builder().student(ana).trainer(bia)
                .status(TrainerStudentStatus.ACTIVE).build()));
        assertThatThrownBy(() -> service.hire(5L, 50L, "ana@example.com")).isInstanceOf(ConflictException.class);
        // menor de idade
        when(links.findByStudentId(9L)).thenReturn(Optional.empty());
        ana.setBirthDate(LocalDate.of(2011, 1, 1));
        assertThatThrownBy(() -> service.hire(5L, 50L, "ana@example.com")).isInstanceOf(ConflictException.class);
        verify(subscriptions, never()).subscribe(anyLong(), anyString());
    }

    @Test
    void hire_reusesAnOldLink_withTheNewTrainer() {
        TrainerStudent old = TrainerStudent.builder().student(ana).trainer(bia).status(TrainerStudentStatus.CANCELED).build();
        when(links.findByStudentId(9L)).thenReturn(Optional.of(old));

        service.hire(5L, 50L, "ana@example.com");

        assertThat(old.getTrainer()).isSameAs(joao);
        assertThat(old.getStatus()).isEqualTo(TrainerStudentStatus.INVITED);
        verify(links).save(eq(old));
    }

    @Test
    void hireByInvite_worksEvenIfTheTrainerIsNotInTheHub_sameRulesOtherwise() {
        joao.setListed(false);
        Plan mensal = plans.findById(50L).orElseThrow();

        assertThat(service.hireByInvite(mensal, "ana@example.com").url()).isEqualTo("https://checkout.stripe.test/x");
        verify(subscriptions).subscribe(50L, "ana@example.com");

        mensal.setActive(false);
        assertThatThrownBy(() -> service.hireByInvite(mensal, "ana@example.com")).isInstanceOf(ConflictException.class);
        mensal.setActive(true);
        when(links.findByStudentId(9L)).thenReturn(Optional.of(TrainerStudent.builder().student(ana).trainer(bia)
                .status(TrainerStudentStatus.ACTIVE).build()));
        assertThatThrownBy(() -> service.hireByInvite(mensal, "ana@example.com")).isInstanceOf(ConflictException.class);
    }
}
