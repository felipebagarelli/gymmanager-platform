import { BrowserRouter, Routes, Route } from "react-router-dom";

import Layout from "./components/layout/Layout";
import RequireAuth from "./components/RequireAuth";
import Dashboard from "./pages/Dashboard";
import Students from "./pages/Students";
import Exercises from "./pages/Exercises";
import Workouts from "./pages/Workouts";
import WorkoutExercise from "./pages/WorkoutExercise";
import Login from "./pages/Login";
import "./App.css";

function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="/login" element={<Login />} />
                <Route
                    path="*"
                    element={
                        <RequireAuth>
                            <Layout>
                                <Routes>
                                    <Route path="/" element={<Dashboard />} />
                                    <Route path="/students" element={<Students />} />
                                    <Route path="/exercises" element={<Exercises />} />
                                    <Route path="/students/:studentId/workouts" element={<Workouts />} />
                                    <Route path="/students/:studentId/workouts/:workoutId/exercises" element={<WorkoutExercise/>}/>
                                </Routes>
                            </Layout>
                        </RequireAuth>
                    }
                />
            </Routes>
        </BrowserRouter>
    );
}

export default App;
