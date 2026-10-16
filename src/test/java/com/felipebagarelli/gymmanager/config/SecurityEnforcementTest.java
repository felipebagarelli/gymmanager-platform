package com.felipebagarelli.gymmanager.config;

import com.felipebagarelli.gymmanager.auth.config.JwtConfig;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.service.JwtService;
import com.felipebagarelli.gymmanager.controller.ExerciseController;
import com.felipebagarelli.gymmanager.controller.WorkoutController;
import com.felipebagarelli.gymmanager.controller.WorkoutExercisesController;
import com.felipebagarelli.gymmanager.exception.GlobalExceptionHandler;
import com.felipebagarelli.gymmanager.service.ExerciseService;
import com.felipebagarelli.gymmanager.service.WorkoutExerciseService;
import com.felipebagarelli.gymmanager.service.WorkoutService;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = {ExerciseController.class, StudentController.class, WorkoutController.class, WorkoutExercisesController.class})
@Import({SecurityConfig.class, CorsConfig.class, JwtConfig.class, JwtService.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = {"jwt.secret=test-secret-used-only-in-security-enforcement-tests-1234567890", "app.cors.allowed-origins=http://localhost:5173"})
class SecurityEnforcementTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @MockitoBean
    private ExerciseService exerciseService;

    @MockitoBean
    private StudentService studentService;

    @MockitoBean
    private WorkoutService workoutService;

    @MockitoBean
    private WorkoutExerciseService workoutExerciseService;

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
        when(exerciseService.allExercises(anyString())).thenReturn(List.of());

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
    void workoutManagement_withStudentRoleToken_returns403() throws Exception {
        String student = "Bearer " + tokenFor(Role.STUDENT);
        mockMvc.perform(post("/workouts/1/duplicate").header("Authorization", student))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/workouts/1/assignments").header("Authorization", student))
                .andExpect(status().isForbidden());
        mockMvc.perform(put("/workout-exercises/workout/1/order")
                        .header("Authorization", student)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"workoutExerciseIds\":[1,2]}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void workoutManagement_withTrainerRoleToken_isAllowed() throws Exception {
        String trainer = "Bearer " + tokenFor(Role.TRAINER);
        when(workoutService.activeAssignments(anyLong(), anyString())).thenReturn(List.of());
        when(workoutExerciseService.reorder(anyLong(), any(), anyString())).thenReturn(List.of());

        mockMvc.perform(get("/workouts/1/assignments").header("Authorization", trainer))
                .andExpect(status().isOk());
        mockMvc.perform(put("/workout-exercises/workout/1/order")
                        .header("Authorization", trainer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"workoutExerciseIds\":[1,2]}"))
                .andExpect(status().isOk());
    }

    @Test
    void reactivateAndPauseStudent_withStudentRoleToken_returns403() throws Exception {
        String student = "Bearer " + tokenFor(Role.STUDENT);
        mockMvc.perform(post("/api/v1/students/2/reactivate").header("Authorization", student))
                .andExpect(status().isForbidden());
        mockMvc.perform(put("/api/v1/students/2/link-status")
                        .header("Authorization", student)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"PAUSED\"}"))
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

    @Test
    void cors_preflightFromAllowedOrigin_isAccepted() throws Exception {
        mockMvc.perform(options("/exercises")
                        .header("Origin", "http://localhost:5173")
                        .header("Access-Control-Request-Method", "GET")
                        .header("Access-Control-Request-Headers", "Authorization"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                        .header().string("Access-Control-Allow-Origin", "http://localhost:5173"));
    }

    @Test
    void cors_preflightFromUnknownOrigin_isRejected() throws Exception {
        mockMvc.perform(options("/exercises")
                        .header("Origin", "http://evil.example.com")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isForbidden());
    }
}
