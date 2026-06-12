import React, { useState, useEffect } from "react";
import {
  BrowserRouter,
  Routes,
  Route,
  Navigate,
  useNavigate,
} from "react-router-dom";
import { Preferences } from "@capacitor/preferences";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";

function ProtectedRoute({ children }) {
  const [checking, setChecking] = useState(true);
  const [hasToken, setHasToken] = useState(false);

  useEffect(() => {
    Preferences.get({ key: "jwt_access" }).then(({ value }) => {
      setHasToken(!!value);
      setChecking(false);
    });
  }, []);

  if (checking) {
    return (
      <div style={{ padding: 40, textAlign: "center", color: "#888" }}>
        Loading…
      </div>
    );
  }

  return hasToken ? children : <Navigate to="/login" replace />;
}

const appStyle = {
  fontFamily:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  minHeight: "100vh",
  margin: 0,
  background: "#f5f5f5",
};

export default function App() {
  return (
    <div style={appStyle}>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Navigate to="/login" replace />} />
          <Route path="/login" element={<Login />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
        </Routes>
      </BrowserRouter>
    </div>
  );
}
