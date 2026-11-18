FROM python:3.13-alpine

RUN apk add --no-cache su-exec \
 && adduser -D user

WORKDIR /opt/rdgen

COPY . .
RUN chmod +x /opt/rdgen/docker-entrypoint.sh \
 && mkdir -p /opt/rdgen/exe /opt/rdgen/png /opt/rdgen/temp_zips \
 && chown -R user:user /opt/rdgen

USER user
ENV PATH="/home/user/.local/bin:${PATH}"
RUN pip install --no-cache-dir -r requirements.txt \
 && python manage.py migrate

USER root
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8000/healthz || exit 1

ENTRYPOINT ["/opt/rdgen/docker-entrypoint.sh"]
CMD ["gunicorn", "-c", "gunicorn.conf.py", "rdgen.wsgi:application"]
