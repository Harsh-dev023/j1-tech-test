"""
URL configuration for the stack validation prototype.
"""
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from api.serializers import JaivorgTokenSerializer


class JaivorgTokenObtainPairView(TokenObtainPairView):
    serializer_class = JaivorgTokenSerializer

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/token/", JaivorgTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/", include("api.urls")),
]
