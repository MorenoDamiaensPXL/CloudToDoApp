FROM node:16-alpine AS build
WORKDIR /usr/src/app

COPY . .

RUN npm install
RUN npm run build --configuration=production

FROM nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /usr/src/app/dist/frontend/ /usr/share/nginx/html
