FROM node:10.15.1

RUN mkdir /ima
WORKDIR /ima

RUN npm install colors web3@1.0.0-beta.35 ethereumjs-tx ethereumjs-wallet ethereumjs-util
RUN npm install --save-dev @babel/plugin-transform-runtime
RUN npm install --save @babel/runtime

COPY . .


CMD ["node", "/ima/agent/run.js"]
#CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

