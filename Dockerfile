FROM node

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY src/index.js .

CMD [ "node", "index.js" ]