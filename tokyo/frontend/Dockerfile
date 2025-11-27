# Frontend Nginx Docker Image
FROM nginx:1.27-alpine

# Remove default nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy ALL files to nginx html directory
COPY . /usr/share/nginx/html/

# Copy env script
COPY env.sh /docker-entrypoint.d/40-env.sh
RUN chmod +x /docker-entrypoint.d/40-env.sh

# Remove non-web files from html directory
RUN rm -rf /usr/share/nginx/html/Dockerfile \
           /usr/share/nginx/html/Dockerrun.aws.json \
           /usr/share/nginx/html/nginx.conf \
           /usr/share/nginx/html/*.zip \
           /usr/share/nginx/html/README.md \
           /usr/share/nginx/html/.ebextensions \
           /usr/share/nginx/html/env.sh \
    && echo "=== Files in /usr/share/nginx/html/ ===" \
    && ls -la /usr/share/nginx/html/ \
    && echo "=== Content of index.html ===" \
    && head -5 /usr/share/nginx/html/index.html || echo "index.html not found!"

# Expose port 8080 (Beanstalk requirement)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
