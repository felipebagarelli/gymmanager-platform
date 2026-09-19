package com.felipebagarelli.gymmanager.config;

import com.felipebagarelli.gymmanager.auth.config.JwtConfig;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.service.JwtService;
import com.felipebagarelli.gymmanager.controller.ExerciseController;
import com.felipebagarelli.gymmanager.exception.GlobalExceptionHandler;
import com.felipebagarelli.gymmanager.service.ExerciseService;
import com.felipebagarelli.gymmanager.student.controller.StudentController;
import com.felipebagarelli.gymmanager.student.dto.request.CreateStudentRequest;
import com.felipebagarelli.gymmanager.student.service.StudentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = {ExerciseController.class, StudentController.class})
@Import({SecurityConfig.class, JwtConfig.class, JwtService.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "jwt.secret=test-secret-used-only-in-security-enforcement-tests-1234567890")
class SecurityEnforcementTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @MockitoBean
    private ExerciseService exerciseService;

    @MockitoBean
    private StudentService studentService;

    private String tokenFor(Role role) {
        User user = User.builder().id(1L).email("user@example.com").role(role).active(true).build();
        return jwtService.generateToken(user);
    }

    @Test
    void legacyEndpoint_withoutToken_returns401() throws Exception {
        mockMvc.perform(get("/exercises"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void legacyEndpoint_withAnyAuthenticatedRole_returns200() throws Exception {
        when(exerciseService.allExercises()).thenReturn(List.of());

        mockMvc.perform(get("/exercises")
                        .header("Authorization", "Bearer " + tokenFor(Role.STUDENT)))
                .andExpect(status().isOk());
    }

    @Test
    void createExercise_withStudentRoleToken_returns403() throws Exception {
        mockMvc.perform(post("/exercises")
                        .header("Authorization", "Bearer " + tokenFor(Role.STUDENT))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Supino\",\"muscleGroup\":\"Peito\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void createStudent_withoutToken_returns401() throws Exception {
        mockMvc.perform(post("/api/v1/trainers/1/students")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validStudentPayload()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createStudent_withStudentRoleToken_returns403() throws Exception {
        mockMvc.perform(post("/api/v1/trainers/1/students")
                        .header("Authorization", "Bearer " + tokenFor(Role.STUDENT))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validStudentPayload()))
                .andExpect(status().isForbidden());
    }

    @Test
    void createStudent_withTrainerTokenButNotTheOwner_returns403() throws Exception {
        when(studentService.createStudent(anyLong(), any(CreateStudentRequest.class), anyString()))
                .thenThrow(new AccessDeniedException("Você não tem permissão para acessar os dados deste personal."));

        mockMvc.perform(post("/api/v1/trainers/1/students")
                        .header("Authorization", "Bearer " + tokenFor(Role.TRAINER))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validStudentPayload()))
                .andExpect(status().isForbidden());
    }

    private String validStudentPayload() {
        return """
                {
                  "email": "aluno@example.com",
                  "password": "senhaSegura123",
                  "name": "Maria Aluna",
                  "birthDate": "%s",
                  "phone": "11988888888",
                  "goal": "hipertrofia"
                }
                """.formatted(LocalDate.of(2000, 1, 1));
    }
}
