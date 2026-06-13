from rest_framework_simplejwt.serializers import TokenObtainPairSerializer


class JaivorgTokenSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Add custom claims
        try:
            token["role"] = user.role
        except Exception:
            token["role"] = "user"
        return token
