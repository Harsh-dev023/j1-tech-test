import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Preferences } from "@capacitor/preferences";
import api from "../api";

const containerStyle = {
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  minHeight: "100vh",
  padding: 20,
};

const cardStyle = {
  background: "#fff",
  borderRadius: 8,
  padding: 32,
  width: "100%",
  maxWidth: 380,
  boxShadow: "0 2px 12px rgba(0,0,0,0.08)",
};

const titleStyle = {
  margin: "0 0 24px",
  fontSize: 22,
  fontWeight: 600,
  textAlign: "center",
  color: "#222",
};

const inputStyle = {
  display: "block",
  width: "100%",
  padding: "10px 12px",
  marginBottom: 14,
  border: "1px solid #ddd",
  borderRadius: 6,
  fontSize: 15,
  boxSizing: "border-box",
  outline: "none",
};

const buttonStyle = {
  display: "block",
  width: "100%",
  padding: "11px 0",
  background: "#2563eb",
  color: "#fff",
  border: "none",
  borderRadius: 6,
  fontSize: 15,
  fontWeight: 600,
  cursor: "pointer",
};

const errorStyle = {
  color: "#dc2626",
  fontSize: 13,
  marginBottom: 12,
  textAlign: "center",
};

export default function Login() {
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const res = await api.post("/token/", { username, password });
      await Preferences.set({ key: "jwt_access", value: res.data.access });
      navigate("/dashboard");
    } catch (err) {
      setError("Invalid credentials");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={containerStyle}>
      <form style={cardStyle} onSubmit={handleSubmit}>
        <h1 style={titleStyle}>Login</h1>

        {error && <div style={errorStyle}>{error}</div>}

        <input
          id="username-input"
          style={inputStyle}
          type="text"
          placeholder="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          autoComplete="username"
          required
        />

        <input
          id="password-input"
          style={inputStyle}
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
          required
        />

        <button
          id="login-button"
          style={{
            ...buttonStyle,
            opacity: loading ? 0.7 : 1,
          }}
          type="submit"
          disabled={loading}
        >
          {loading ? "Signing in…" : "Sign In"}
        </button>
      </form>
    </div>
  );
}
