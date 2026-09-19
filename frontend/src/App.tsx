import { BrowserRouter, Routes, Route } from "react-router-dom";

import Layout from "./components/layout/Layout";
import Dashboard from "./pages/Dashboard";
import Members from "./pages/Members";
import Exercises from "./pages/Exercises";
import Workouts from "./pages/Workouts";
import WorkoutExercise from "./pages/WorkoutExercise";
import "./App.css";

function App() {
    return (
        <BrowserRouter>
            <Layout>
                <Routes>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/members" element={<Members />} />
                    <Route path="/exercises" element={<Exercises />} />
                    <Route path="/members/:memberId/workouts" element={<Workouts />} />
                    <Route path="/members/:memberId/workouts/:workoutId/exercises" element={<WorkoutExercise/>}/>
                </Routes>
            </Layout>
        </BrowserRouter>
    );
}

export default App;