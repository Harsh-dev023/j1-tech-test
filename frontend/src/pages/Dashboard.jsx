import React, { useState, useEffect } from "react";
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
  maxWidth: 480,
  boxShadow: "0 2px 12px rgba(0,0,0,0.08)",
  textAlign: "center",
};

const titleStyle = {
  margin: "0 0 8px",
  fontSize: 22,
  fontWeight: 600,
  color: "#222",
};

const messageStyle = {
  fontSize: 16,
  color: "#16a34a",
  background: "#f0fdf4",
  border: "1px solid #bbf7d0",
  borderRadius: 6,
  padding: "14px 18px",
  margin: "20px 0",
};

const userStyle = {
  fontSize: 14,
  color: "#666",
  marginBottom: 24,
};

const buttonStyle = {
  padding: "10px 28px",
  background: "#dc2626",
  color: "#fff",
  border: "none",
  borderRadius: 6,
  fontSize: 14,
  fontWeight: 600,
  cursor: "pointer",
};

const errorStyle = {
  color: "#dc2626",
  fontSize: 14,
  margin: "20px 0",
};

export default function Dashboard() {
  const navigate = useNavigate();
  const [message, setMessage] = useState("");
  const [user, setUser] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api
      .get("/protected/")
      .then((res) => {
        setMessage(res.data.message);
        setUser(res.data.user);
      })
      .catch((err) => {
        setError("Failed to load protected data.");
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const handleLogout = async () => {
    await Preferences.remove({ key: "jwt_access" });
    navigate("/login");
  };

  if (loading) {
    return (
      <div style={containerStyle}>
        <div style={{ color: "#888", fontSize: 16 }}>Loading…</div>
      </div>
    );
  }

  return (
    <div style={containerStyle}>
      <div style={cardStyle}>
        <h1 style={titleStyle}>Dashboard</h1>

        {error ? (
          <div style={errorStyle}>{error}</div>
        ) : (
          <>
            <div style={messageStyle}>{message}</div>
            <div style={userStyle}>
              Authenticated as: <strong>{user}</strong>
            </div>
          </>
        )}

        <button id="logout-button" style={buttonStyle} onClick={handleLogout}>
          Logout
        </button>
      </div>
    </div>
  );
}
