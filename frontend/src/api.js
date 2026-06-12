import axios from "axios";
import { Capacitor } from "@capacitor/core";
import { Preferences } from "@capacitor/preferences";

const isNative = Capacitor.isNativePlatform();

const api = axios.create({
  baseURL: isNative ? "http://10.0.2.2:8000/api" : "/api",
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use(async (config) => {
  const { value } = await Preferences.get({ key: "jwt_access" });
  if (value) {
    config.headers.Authorization = `Bearer ${value}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response && error.response.status === 401) {
      await Preferences.remove({ key: "jwt_access" });
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export default api;
