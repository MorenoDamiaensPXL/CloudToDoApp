# === Build fase ===
FROM node:16-alpine AS build
WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build --configuration=production

# === Runtime fase (nginx) ===
FROM nginx:alpine

# Kopieer custom nginx-config
COPY nginx.conf /etc/nginx/nginx.conf

# Kopieer de gebuilde Angular-bestanden
COPY --from=build /usr/src/app/dist/frontend/ /usr/share/nginx/html

# Voeg je startscript toe voor dynamische API URL injectie
COPY start.sh /docker-entrypoint.d/99-replace-apiurl.sh
RUN chmod +x /docker-entrypoint.d/99-replace-apiurl.sh

# Expose port 80 (standaard nginx)
EXPOSE 80
