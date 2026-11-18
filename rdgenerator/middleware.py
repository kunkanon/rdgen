"""
HTTP Basic Auth for the human-facing generator UI.

GitHub Actions callbacks (get_zip, save_custom_client, get_png, cleanzip, …)
stay open — they need GENURL without a browser login. Abuse surface there is
UUID-scoped; the public risk was anyone opening / and clicking Generate.

Env:
  RDGEN_BASIC_USER / RDGEN_BASIC_PASSWORD — credentials for UI paths.
  RDGEN_ALLOW_OPEN_UI=1 — local/dev only: allow UI without Basic Auth.
    Production must set BASIC creds; without them UI stays locked (401).
"""
import base64
import hmac
import logging
from django.conf import settings
from django.http import HttpResponse


logger = logging.getLogger(__name__)

# Paths Actions + portal worker + healthcheck need without Basic Auth
PUBLIC_PREFIXES = (
    '/healthz',
    '/get_zip',
    '/save_custom_client',
    '/get_png',
    '/cleanzip',
    '/creategh',
    '/updategh',
    '/startgh',
    '/download',
    '/check_for_file',
)


def _configured():
    user = (getattr(settings, 'RDGEN_BASIC_USER', None) or '').strip()
    password = (getattr(settings, 'RDGEN_BASIC_PASSWORD', None) or '').strip()
    return user, password


def _allow_open_ui():
    return str(getattr(settings, 'RDGEN_ALLOW_OPEN_UI', '') or '').strip().lower() in (
        '1', 'true', 'yes', 'on',
    )


class RdgenBasicAuthMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        user, password = _configured()
        if not user or not password:
            if _allow_open_ui():
                logger.warning(
                    'RDGen UI is OPEN (RDGEN_ALLOW_OPEN_UI=1, no BASIC creds). '
                    'Do not use this in production.'
                )
            else:
                logger.warning(
                    'RDGen UI locked: set RDGEN_BASIC_USER/PASSWORD '
                    '(or RDGEN_ALLOW_OPEN_UI=1 for local only).'
                )

    def __call__(self, request):
        path = request.path or '/'
        if any(path.startswith(p) for p in PUBLIC_PREFIXES):
            return self.get_response(request)

        user, password = _configured()
        if not user or not password:
            if _allow_open_ui():
                return self.get_response(request)
            response = HttpResponse(
                'RDGen UI locked: set RDGEN_BASIC_USER and RDGEN_BASIC_PASSWORD',
                status=401,
            )
            response['WWW-Authenticate'] = 'Basic realm="Tidrax RDGen"'
            return response

        auth = request.META.get('HTTP_AUTHORIZATION', '')
        if auth.startswith('Basic '):
            try:
                decoded = base64.b64decode(auth[6:]).decode('utf-8')
                u, _, p = decoded.partition(':')
                if hmac.compare_digest(u, user) and hmac.compare_digest(p, password):
                    return self.get_response(request)
            except Exception:
                pass

        response = HttpResponse('Authentication required', status=401)
        response['WWW-Authenticate'] = 'Basic realm="Tidrax RDGen"'
        return response
