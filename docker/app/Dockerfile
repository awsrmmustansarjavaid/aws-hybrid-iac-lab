# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION LAB
# Docker Application Image
# ==========================================================


# ----------------------------------------------------------
# 1. Base Image
# ----------------------------------------------------------
# Use the lightweight Alpine version of Nginx.
#
# Nginx will act as the web server for our application.
# ----------------------------------------------------------

FROM nginx:alpine


# ----------------------------------------------------------
# 2. Application Files
# ----------------------------------------------------------
# Copy our application HTML file into the default
# Nginx web root.
#
# Nginx serves files from:
#
# /usr/share/nginx/html
# ----------------------------------------------------------

COPY app/index.html /usr/share/nginx/html/index.html


# ----------------------------------------------------------
# 3. Container Port
# ----------------------------------------------------------
# Document that the application listens on HTTP port 80.
#
# IMPORTANT:
# EXPOSE does NOT publish the port to the host.
# Port publishing is done when running the container.
# ----------------------------------------------------------

EXPOSE 80


# ----------------------------------------------------------
# 4. Start Nginx
# ----------------------------------------------------------
# Run Nginx in the foreground.
#
# Docker containers need a foreground process to remain
# running. Therefore we use:
#
# nginx -g "daemon off;"
# ----------------------------------------------------------

CMD ["nginx", "-g", "daemon off;"]