import axios from "axios";
import { Capacitor } from "@capacitor/core";
import { Preferences } from "@capacitor/preferences";

const isNative = Capacitor.isNativePlatform();

const baseHost = import.meta.env.VITE_API_URL
  ? import.meta.env.VITE_API_URL
  : isNative
  ? "http://10.0.2.2:8000"
  : "http://localhost:8000";

const api = axios.create({
  baseURL: `${baseHost}/api`,
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use(async (config) => {
  const { value } = await Preferences.get({ key: "jwt_access" });
  if (value) {
    config.headers = config.headers || {};
    config.headers.Authorization = `Bearer ${value}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    if (
      error.response &&
      error.response.status === 401 &&
      !originalRequest?._retry
    ) {
      originalRequest._retry = true;
      const { value: refresh } = await Preferences.get({ key: "jwt_refresh" });
      if (refresh) {
        try {
          const refreshRes = await axios.post(
            `${baseHost}/api/token/refresh/`,
            { refresh },
            { headers: { "Content-Type": "application/json" } }
          );
          const newAccess = refreshRes.data?.access;
          if (newAccess) {
            await Preferences.set({ key: "jwt_access", value: newAccess });
            // set header and retry original request
            originalRequest.headers = originalRequest.headers || {};
            originalRequest.headers.Authorization = `Bearer ${newAccess}`;
            return api(originalRequest);
          }
        } catch (e) {
          // refresh failed, fall through to logout
        }
      }
      // cleanup and force login
      await Preferences.remove({ key: "jwt_access" });
      await Preferences.remove({ key: "jwt_refresh" });
      if (typeof window !== "undefined") {
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export default api;
